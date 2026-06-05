import { ClerkProvider, Show, SignInButton, UserButton } from "@clerk/nextjs";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="fr">
        <body>
          <header style={{ display: "flex", justifyContent: "flex-end", padding: 12 }}>
            <Show when="signed-out"><SignInButton /></Show>
            <Show when="signed-in"><UserButton /></Show>
          </header>
          <main>{children}</main>
        </body>
      </html>
    </ClerkProvider>
  );
}
