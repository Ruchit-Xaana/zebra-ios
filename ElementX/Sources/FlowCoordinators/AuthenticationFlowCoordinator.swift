//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Combine
import SwiftUI

@MainActor
protocol AuthenticationFlowCoordinatorDelegate: AnyObject {
    func authenticationFlowCoordinator(didLoginWithSession userSession: UserSessionProtocol)
}

class AuthenticationFlowCoordinator: FlowCoordinatorProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let bugReportService: BugReportServiceProtocol
    private let navigationRootCoordinator: NavigationRootCoordinator
    private let navigationStackCoordinator: NavigationStackCoordinator
    private let appMediator: AppMediatorProtocol
    private let appSettings: AppSettings
    private let analytics: AnalyticsService
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let qrCodeLoginService: QRCodeLoginServiceProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    private var oidcPresenter: OIDCAuthenticationPresenter?
    
    // periphery:ignore - retaining purpose
    private var bugReportFlowCoordinator: BugReportFlowCoordinator?
    
    weak var delegate: AuthenticationFlowCoordinatorDelegate?
    
    init(authenticationService: AuthenticationServiceProtocol,
         qrCodeLoginService: QRCodeLoginServiceProtocol,
         bugReportService: BugReportServiceProtocol,
         navigationRootCoordinator: NavigationRootCoordinator,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         analytics: AnalyticsService,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.bugReportService = bugReportService
        self.navigationRootCoordinator = navigationRootCoordinator
        self.appMediator = appMediator
        self.appSettings = appSettings
        self.analytics = analytics
        self.userIndicatorController = userIndicatorController
        self.qrCodeLoginService = qrCodeLoginService
        
        navigationStackCoordinator = NavigationStackCoordinator()
    }
    
    func start() {
        showStartScreen()
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        fatalError()
    }
    
    func clearRoute(animated: Bool) {
        fatalError()
    }
    
    func handleOIDCRedirectURL(_ url: URL) {
        guard let oidcPresenter else {
            MXLog.error("Failed to find an OIDC request in progress.")
            return
        }
        
        oidcPresenter.handleUniversalLinkCallback(url)
    }
    
    // MARK: - Private
    
    private func showStartScreen() {
        let parameters = AuthenticationStartScreenParameters(webRegistrationEnabled: appSettings.webRegistrationEnabled)
        let coordinator = AuthenticationStartScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .loginManually:
                    Task { await self.startAuthentication(flow: .login) }
                case .loginWithQR:
                    startQRCodeLogin()
                case .register:
                    Task { await self.startAuthentication(flow: .register) }
                case .reportProblem:
                    showReportProblemScreen()
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.setRootCoordinator(coordinator)
        
        navigationRootCoordinator.setRootCoordinator(navigationStackCoordinator)
    }
    
    private func startQRCodeLogin() {
        let coordinator = QRCodeLoginScreenCoordinator(parameters: .init(qrCodeLoginService: qrCodeLoginService,
                                                                         orientationManager: appMediator.windowManager,
                                                                         appMediator: appMediator))
        coordinator.actionsPublisher.sink { [weak self] action in
            guard let self else {
                return
            }
            switch action {
            case .signInManually:
                navigationStackCoordinator.setSheetCoordinator(nil)
                Task { await self.startAuthentication(flow: .login) }
            case .cancel:
                navigationStackCoordinator.setSheetCoordinator(nil)
            case .done(let userSession):
                navigationStackCoordinator.setSheetCoordinator(nil)
                // Since the qr code login flow includes verification
                appSettings.hasRunIdentityConfirmationOnboarding = true
                DispatchQueue.main.async {
                    self.userHasSignedIn(userSession: userSession)
                }
            }
        }
        .store(in: &cancellables)
        navigationStackCoordinator.setSheetCoordinator(coordinator)
    }
    
    private func showReportProblemScreen() {
        bugReportFlowCoordinator = BugReportFlowCoordinator(parameters: .init(presentationMode: .sheet(navigationStackCoordinator),
                                                                              userIndicatorController: userIndicatorController,
                                                                              bugReportService: bugReportService,
                                                                              userSession: nil))
        bugReportFlowCoordinator?.start()
    }
    
    private func startAuthentication(flow: AuthenticationFlow) async {
        startLoading()
        
        switch await authenticationService.configure(for: appSettings.defaultHomeserverAddress) {
        case .success:
            stopLoading()
            showServerConfirmationScreen(authenticationFlow: flow)
        case .failure:
            stopLoading()
            showServerSelectionScreen(authenticationFlow: flow, isModallyPresented: false)
        }
    }
    
    private func showServerSelectionScreen(authenticationFlow: AuthenticationFlow, isModallyPresented: Bool) {
        let navigationCoordinator = NavigationStackCoordinator()
        
        let parameters = ServerSelectionScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                    userIndicatorController: userIndicatorController,
                                                                    isModallyPresented: isModallyPresented)
        let coordinator = ServerSelectionScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .updated:
                    if isModallyPresented {
                        navigationStackCoordinator.setSheetCoordinator(nil)
                    } else {
                        // We are here because the default server failed to respond.
                        if authenticationService.homeserver.value.loginMode == .password {
                            if authenticationFlow == .login {
                                // Add the password login screen directly to the flow, its fine.
                                showLoginScreen()
                            } else {
                                // Add the web registration screen directly to the flow, its fine.
                                showWebRegistration()
                            }
                        } else {
                            // OIDC is presented from the confirmation screen so replace the
                            // server selection screen which was inserted to handle the failure.
                            navigationStackCoordinator.pop()
                            showServerConfirmationScreen(authenticationFlow: authenticationFlow)
                        }
                    }
                case .dismiss:
                    navigationStackCoordinator.setSheetCoordinator(nil)
                }
            }
            .store(in: &cancellables)
        
        if isModallyPresented {
            navigationCoordinator.setRootCoordinator(coordinator)
            navigationStackCoordinator.setSheetCoordinator(navigationCoordinator)
        } else {
            navigationStackCoordinator.push(coordinator)
        }
    }
    
    private func showServerConfirmationScreen(authenticationFlow: AuthenticationFlow) {
        let parameters = ServerConfirmationScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                       authenticationFlow: authenticationFlow)
        let coordinator = ServerConfirmationScreenCoordinator(parameters: parameters)
        
        coordinator.actions.sink { [weak self] action in
            guard let self else { return }
            
            switch action {
            case .continue(let window):
                if authenticationService.homeserver.value.loginMode == .oidc, let window {
                    showOIDCAuthentication(presentationAnchor: window)
                } else if authenticationFlow == .register {
                    showWebRegistration()
                } else {
                    showLoginScreen()
                }
            case .changeServer:
                showServerSelectionScreen(authenticationFlow: authenticationFlow, isModallyPresented: true)
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func showWebRegistration() {
        let parameters = WebRegistrationScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                    userIndicatorController: userIndicatorController)
        let coordinator = WebRegistrationScreenCoordinator(parameters: parameters)
        
        coordinator.actionsPublisher.sink { [weak self] action in
            guard let self else { return }
            
            switch action {
            case .cancel:
                navigationStackCoordinator.setSheetCoordinator(nil)
            case .signedIn(let userSession):
                userHasSignedIn(userSession: userSession)
            }
        }
        .store(in: &cancellables)
        
        navigationStackCoordinator.setSheetCoordinator(coordinator)
    }
    
    private func showOIDCAuthentication(presentationAnchor: UIWindow) {
        startLoading()
        
        Task {
            switch await authenticationService.urlForOIDCLogin() {
            case .failure(let error):
                stopLoading()
                handleError(error)
            case .success(let oidcData):
                stopLoading()
                
                let presenter = OIDCAuthenticationPresenter(authenticationService: authenticationService,
                                                            oidcRedirectURL: appSettings.oidcRedirectURL,
                                                            presentationAnchor: presentationAnchor)
                self.oidcPresenter = presenter
                switch await presenter.authenticate(using: oidcData) {
                case .success(let userSession):
                    userHasSignedIn(userSession: userSession)
                case .failure(let error):
                    handleError(error)
                }
                oidcPresenter = nil
            }
        }
    }
    
    private func showLoginScreen() {
        let parameters = LoginScreenCoordinatorParameters(authenticationService: authenticationService,
                                                          analytics: analytics,
                                                          userIndicatorController: userIndicatorController)
        let coordinator = LoginScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }

                switch action {
                case .signedIn(let userSession):
                    userHasSignedIn(userSession: userSession)
                case .configuredForOIDC:
                    // Pop back to the confirmation screen for OIDC login to continue.
                    navigationStackCoordinator.pop(animated: false)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
        
    private func userHasSignedIn(userSession: UserSessionProtocol) {
        delegate?.authenticationFlowCoordinator(didLoginWithSession: userSession)
    }
    
    private static let loadingIndicatorIdentifier = "\(AuthenticationFlowCoordinator.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
    
    /// Processes an error to either update the flow or display it to the user.
    private func handleError(_ error: AuthenticationServiceError) {
        MXLog.warning("Error occurred: \(error)")
        
        switch error {
        case .oidcError(.notSupported):
            // Temporary alert hijacking the use of .notSupported, can be removed when OIDC support is in the SDK.
            userIndicatorController.alertInfo = AlertInfo(id: UUID(),
                                                          title: L10n.commonError,
                                                          message: L10n.commonServerNotSupported)
        case .oidcError(.userCancellation):
            // No need to show an error, the user cancelled authentication.
            break
        default:
            userIndicatorController.alertInfo = AlertInfo(id: UUID())
        }
    }
}
