import SwiftUI

/// Sign-in / create-account screen (v2 backend foundation). Talks to the store's
/// AuthService — local today, Firebase once connected. Sign in with Apple
/// arrives once the backend can verify it.
struct AuthView: View {
    @Environment(MorpheAppStore.self) private var store

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var role: UserRole = .athlete

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MORPHE")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(MorpheTheme.accent)
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text(isSignUp ? "Transform. Evolve. Become." : "Sign in to keep your training going.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    .padding(.top, 48)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            if isSignUp {
                                labeledField("Name") {
                                    TextField("Your name", text: $name)
                                        .textContentType(.name)
                                        .textFieldStyle(MorpheFieldStyle())
                                }
                                labeledField("I'm a...") {
                                    Picker("Role", selection: $role) {
                                        ForEach(UserRole.allCases) { option in
                                            Text(option.title).tag(option)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }

                            labeledField("Email") {
                                // A plain word, not an example address — the
                                // system paints addresses link-blue.
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(MorpheFieldStyle())
                            }
                            labeledField("Password") {
                                SecureField("At least 6 characters", text: $password)
                                    .textContentType(isSignUp ? .newPassword : .password)
                                    .textFieldStyle(MorpheFieldStyle())
                            }

                            if !isSignUp {
                                Button("Forgot password?") {
                                    Task { await store.requestPasswordReset(email: email) }
                                }
                                .buttonStyle(.plain)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accent)
                                .accessibilityLabel("Send a password reset email")
                            }

                            if let error = store.authErrorMessage {
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.danger)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack(spacing: 8) {
                                    if store.isAuthBusy { ProgressView().tint(.black) }
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .disabled(store.isAuthBusy)

                            // Sign in with Apple returns here once it's wired
                            // to the backend — a permanently disabled button
                            // is an App Review flag, not a feature preview.
                        }
                    }

                    Button(isSignUp ? "Sign In" : "Create Account") {
                        withAnimation {
                            isSignUp.toggle()
                            store.authErrorMessage = nil
                        }
                    }
                    .accessibilityLabel(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
    }

    private func submit() async {
        if isSignUp {
            await store.signUp(email: email, password: password, role: role, name: name)
        } else {
            await store.signIn(email: email, password: password)
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.textSecondary)
            content()
        }
    }
}
