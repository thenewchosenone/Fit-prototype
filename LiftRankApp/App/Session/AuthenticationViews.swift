import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode = "Sign In"
    @State private var email = ""
    @State private var password = ""
    @State private var showingPassword = false
    @State private var showingReset = false
    @State private var showingPlanPreview = false
    @State private var legalPage: SettingsInfoPage?
    @State private var resetEmail = ""
    @State private var resetError: String?
    @State private var appleNonce = ""
    @State private var confirmationEmail: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    private let emailConfirmationMessage = "Check your email to confirm your account, then sign in."
    private let emailResentMessage = "A new confirmation email is on the way."

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 16) {
                    if focusedField == nil {
                        BrandLogoMark()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Lift Rivals").font(.title.bold())
                        Text(mode == "Sign In" ? "Welcome back. Sign in to continue." : "Create your account to save and sync your training.")
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                    }

                    if appState.accountStatus == .configurationRequired {
                        Label("Account services are not configured in this development build.", systemImage: "wrench.and.screwdriver.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftGold)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftGold.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Picker("Account action", selection: $mode) {
                            Text("Sign In").tag("Sign In")
                            Text("Create Account").tag("Create Account")
                        }
                        .pickerStyle(.segmented)
                        .disabled(appState.accountOperationInProgress)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            TextField("", text: $email)
                                .accessibilityLabel("Email")
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .frame(minHeight: 52)
                                .background(Color.liftField)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Password").font(.caption.weight(.semibold)).foregroundStyle(Color.liftMuted)
                            HStack(spacing: 10) {
                                Group {
                                    if showingPassword {
                                        TextField("Password", text: $password)
                                            .focused($focusedField, equals: .password)
                                    } else {
                                        SecureField("Password", text: $password)
                                            .focused($focusedField, equals: .password)
                                    }
                                }
                                .submitLabel(.done)
                                .textContentType(mode == "Sign In" ? .password : .newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    showingPassword.toggle()
                                } label: {
                                    Image(systemName: showingPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(Color.liftMuted)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel(showingPassword ? "Hide password" : "Show password")
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .background(Color.liftField)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        .onSubmit {
                            focusedField = focusedField == .email ? .password : nil
                        }

                        if mode == "Create Account" {
                            Text("At least 10 characters")
                                .font(.caption)
                                .foregroundStyle(Color.liftMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Button("Forgot password?") {
                                focusedField = nil
                                resetEmail = email
                                resetError = nil
                                showingReset = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftAccentText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .disabled(appState.accountOperationInProgress)
                        }

                        if let confirmationEmail {
                            emailConfirmationNotice(for: confirmationEmail)
                        }
                        if let message = appState.accountMessage,
                           confirmationEmail == nil || (message != emailConfirmationMessage && message != emailResentMessage) {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(
                                    message == "Email or password is incorrect. Check both and try again."
                                        ? .red
                                        : (message.localizedCaseInsensitiveContains("connection") || message.localizedCaseInsensitiveContains("network")
                                            ? Color.liftGold
                                            : Color.liftMuted)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Please wait…" : mode,
                            symbolName: mode == "Sign In" ? "arrow.right.circle.fill" : "person.badge.plus"
                        ) {
                            focusedField = nil
                            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !normalizedEmail.isEmpty else {
                                appState.accountMessage = "Enter your email address."
                                return
                            }
                            guard normalizedEmail.contains("@") else {
                                appState.accountMessage = "Enter a valid email address."
                                return
                            }
                            guard !password.isEmpty else {
                                appState.accountMessage = "Enter your password."
                                return
                            }
                            guard mode == "Sign In" || password.count >= 10 else {
                                appState.accountMessage = "New passwords must contain at least 10 characters."
                                return
                            }
                            Task {
                                if mode == "Sign In" {
                                    appState.selectedTab = 0
                                    await appState.signIn(email: normalizedEmail, password: password)
                                    if appState.accountMessage == "Confirm your email before signing in." {
                                        confirmationEmail = normalizedEmail
                                    }
                                } else {
                                    await appState.signUp(email: normalizedEmail, password: password)
                                    if appState.accountMessage == emailConfirmationMessage {
                                        confirmationEmail = normalizedEmail
                                        password = ""
                                        mode = "Sign In"
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("authentication.email.submit")
                        .disabled(appState.accountOperationInProgress)

#if !DEBUG
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.liftOverlay).frame(height: 1)
                            Text("or").font(.caption).foregroundStyle(Color.liftMuted)
                            Rectangle().fill(Color.liftOverlay).frame(height: 1)
                        }
                        .accessibilityHidden(true)
                        SignInWithAppleButton(.continue) { request in
                            let nonce = AppleNonce.make()
                            appleNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = AppleNonce.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                      let data = credential.identityToken,
                                      let token = String(data: data, encoding: .utf8),
                                      !appleNonce.isEmpty else {
                                    appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                                    return
                                }
                                let fullName = AppleIdentityStore.displayName(from: credential.fullName)
                                Task {
                                    appState.selectedTab = 0
                                    await appState.signInWithApple(
                                        identityToken: token,
                                        nonce: appleNonce,
                                        appleUserIdentifier: credential.user,
                                        fullName: fullName
                                    )
                                }
                            case .failure(let error):
                                if let authorizationError = error as? ASAuthorizationError,
                                   authorizationError.code == .canceled {
                                    return
                                }
                                appState.accountMessage = "Sign in with Apple could not be completed. Please try again."
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .disabled(appState.accountOperationInProgress)
#endif

                    }

#if DEBUG
                    if AppState.allowsDemoMode {
                        Button("Explore demo") {
                            Task { await appState.enterDemoMode() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                    }
#endif
                    guestEntry
                    HStack(spacing: 20) {
                        Button("Terms of Use") { legalPage = .terms }
                        Button("Privacy Notice") { legalPage = .privacy }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.liftAccentText)
                    if mode == "Create Account" && focusedField == nil {
                        Button("Preview training plans") { showingPlanPreview = true }
                            .font(.subheadline)
                            .foregroundStyle(Color.liftAccentText)
                    }
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: mode) { _, _ in
            focusedField = nil
            appState.accountMessage = nil
        }
        .onChange(of: email) { _, value in
            if let confirmationEmail,
               value.trimmingCharacters(in: .whitespacesAndNewlines) != confirmationEmail {
                self.confirmationEmail = nil
                appState.accountMessage = nil
            }
        }
        .sheet(item: $legalPage) { page in
            NavigationStack {
                SettingsInfoView(page: page)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close", systemImage: "xmark") { legalPage = nil }.labelStyle(.iconOnly)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingPlanPreview) {
            StarterPlanPreviewView {
                showingPlanPreview = false
                mode = "Create Account"
            }
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                Form {
                    Section {
                        Text("Enter your account email and we’ll send a secure reset link. Open it on this device to choose a new password in Lift Rivals.")
                            .font(.subheadline)
                            .foregroundStyle(Color.liftMuted)
                        TextField("Email", text: $resetEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if let resetError {
                        Text(resetError).foregroundStyle(Color.liftRed)
                            .accessibilityIdentifier("authentication.reset.error")
                    }
                    Section {
                        Button(appState.accountOperationInProgress ? "Sending…" : "Send reset link") {
                            let normalizedEmail = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard normalizedEmail.contains("@") else {
                                resetError = "Enter a valid email address."
                                return
                            }
                            resetError = nil
                            Task {
                                await appState.requestPasswordReset(email: normalizedEmail)
                                if appState.accountMessage == "If an account can receive a reset email, instructions are on the way." {
                                    showingReset = false
                                } else {
                                    resetError = appState.accountMessage
                                }
                            }
                        }
                        .disabled(appState.accountOperationInProgress)
                    }
                }
                .navigationTitle("Reset password")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingReset = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private var guestEntry: some View {
        VStack(spacing: 8) {
            Divider().overlay(Color.liftOverlay)
            Button {
                Task { await appState.enterGuestMode() }
            } label: {
                Label("Create a guest profile", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(Color.liftAccentText)
            .disabled(appState.accountOperationInProgress)
            Text("Set up a username without an email. Add an email in Settings to keep access on another device.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.liftBackground)
    }

    private func emailConfirmationNotice(for email: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Confirm your email", systemImage: "envelope.badge.fill")
                .font(LiftTypography.cardTitle)
                .foregroundStyle(Color.liftAccentText)

            Text("Check your inbox for the confirmation link for")
                .font(.subheadline)
                .foregroundStyle(Color.liftMuted)

            Text(email)
                .font(LiftTypography.rowEmphasis)
                .textSelection(.enabled)

            Text("Open the link in your email to continue. Sign in if prompted. Check spam if the email does not arrive.")
                .font(.caption)
                .foregroundStyle(Color.liftMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await appState.resendConfirmationEmail(email: email) }
            } label: {
                Label(
                    appState.accountOperationInProgress ? "Sending…" : "Send again",
                    systemImage: "arrow.clockwise"
                )
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.liftAccentText)
            .disabled(appState.accountOperationInProgress)
            .accessibilityIdentifier("authentication.confirmation.resend")

            if appState.accountMessage == emailResentMessage {
                Text(emailResentMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftAccentText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liftBlue.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.liftBlue.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("authentication.confirmation.notice")
    }
}

struct PasswordUpdateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case password
        case confirmation
    }

    private var hasMinimumLength: Bool { password.count >= 10 }
    private var passwordsMatch: Bool { !confirmation.isEmpty && password == confirmation }
    private var canSubmit: Bool { hasMinimumLength && passwordsMatch }

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.liftLime.opacity(0.15))
                                    .frame(width: 58, height: 58)
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(Color.liftAccentText)
                            }

                            Text("Choose a new password")
                                .font(.title.weight(.semibold))
                            Text("Your recovery link is verified. Set a new password to secure your Lift Rivals account.")
                                .font(.subheadline)
                                .foregroundStyle(Color.liftMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 13) {
                            secureInput(
                                label: "New password",
                                placeholder: "Enter a new password",
                                text: $password,
                                field: .password
                            )
                            secureInput(
                                label: "Confirm new password",
                                placeholder: "Enter it again",
                                text: $confirmation,
                                field: .confirmation
                            )
                        }

                        LiftCard(padding: 15, radius: 18) {
                            VStack(alignment: .leading, spacing: 11) {
                                Text("Password requirements")
                                    .font(LiftTypography.rowEmphasis)
                                requirementRow(
                                    "At least 10 characters",
                                    isSatisfied: hasMinimumLength,
                                    isError: !password.isEmpty && !hasMinimumLength
                                )
                                requirementRow(
                                    confirmation.isEmpty ? "Confirm your password" : passwordsMatch ? "Passwords match" : "Passwords do not match",
                                    isSatisfied: passwordsMatch,
                                    isError: !confirmation.isEmpty && !passwordsMatch
                                )
                            }
                        }

                        if let message = appState.accountMessage {
                            Label {
                                Text(message)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .foregroundStyle(Color.liftRed)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.liftRed.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        PrimaryButton(
                            title: appState.accountOperationInProgress ? "Updating…" : "Update password",
                            symbolName: appState.accountOperationInProgress ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill"
                        ) {
                            Task { await appState.updatePassword(password) }
                        }
                        .disabled(appState.accountOperationInProgress || !canSubmit)
                        .accessibilityIdentifier("authentication.password.update")

                        Text("If this link expires or stops working, request a new reset email from the sign-in screen.")
                            .font(.caption)
                            .foregroundStyle(Color.liftMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Account recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { Task { await appState.signOutAccount() } }
                        .disabled(appState.accountOperationInProgress)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func secureInput(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(LiftTypography.compactEmphasis)
                .foregroundStyle(Color.liftMuted)
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                    .frame(width: 20)
                SecureField(placeholder, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .password ? .next : .done)
                    .onSubmit {
                        if field == .password { focusedField = .confirmation }
                    }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color.liftField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == field ? Color.liftLime.opacity(0.75) : Color.clear, lineWidth: 1.5)
            }
        }
        .onChange(of: text.wrappedValue) { _, _ in
            if appState.accountMessage != nil { appState.accountMessage = nil }
        }
    }

    private func requirementRow(_ title: String, isSatisfied: Bool, isError: Bool) -> some View {
        Label(title, systemImage: isSatisfied ? "checkmark.circle.fill" : isError ? "xmark.circle.fill" : "circle")
            .font(.caption)
            .foregroundStyle(isSatisfied ? Color.liftAccentText : isError ? Color.liftRed : Color.liftMuted)
    }
}

private enum AppleNonce {
    static func make(length: Int = 32) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString }
        for byte in bytes { result.append(alphabet[Int(byte) % alphabet.count]) }
        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct StarterPlanPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var strength = true
    @State private var homeTraining = false
    @State private var beginner = true
    @State private var days = 3
    let onContinue: () -> Void

    private var template: WorkoutProgramTemplate? {
        WorkoutProgramCatalog.template(id: homeTraining ? "bodyweight_home_12" : beginner ? "full_body_foundation_12" : "adaptive_\(strength ? "strength" : "hypertrophy")_\(days)d_12")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your training") {
                    Picker("Goal", selection: $strength) {
                        Text("Build strength").tag(true)
                        Text("Build muscle").tag(false)
                    }
                    Picker("Equipment", selection: $homeTraining) {
                        Text("Full gym").tag(false)
                        Text("Bodyweight + pull-up bar").tag(true)
                    }
                    Toggle("New to structured training", isOn: $beginner)
                    if !homeTraining && !beginner {
                        Stepper("\(days) days per week", value: $days, in: 2...6)
                    }
                }
                if let template {
                    Section("Your plan preview") {
                        Text(template.name).font(.headline)
                        Text(template.summary).font(.subheadline)
                        Text("\(template.daysPerWeek) workouts per week · \(template.level.rawValue)")
                            .foregroundStyle(Color.liftMuted)
                        if homeTraining || beginner {
                            Text("This foundation uses three training days for balanced practice and recovery.")
                                .font(.caption)
                        }
                    }
                    ForEach(Array(template.sessions.enumerated()), id: \.offset) { index, session in
                        Section("Workout \(index + 1) · \(session.name)") {
                            ForEach(Array(session.exercises.enumerated()), id: \.offset) { _, exercise in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(MockData.trainingExerciseLibrary.first { $0.id == exercise.exerciseID }?.name ?? exercise.exerciseID)
                                    Text("\(exercise.sets) sets × \(exercise.reps) · \(exercise.restSeconds)s rest")
                                        .font(.caption)
                                        .foregroundStyle(Color.liftMuted)
                                }
                            }
                        }
                    }
                    Section {
                        Text("After creating your profile, choose \(template.name) in the plan library to review and activate it. This preview does not start a workout.")
                            .font(.subheadline)
                        Button("Create account") { onContinue() }
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Find your starting plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) }
            }
        }
    }
}
