import { ClerkProvider, SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <ClerkProvider>
      <html lang="fr">
        <body>
          <header style={{ display: "flex", justifyContent: "flex-end", padding: 12 }}>
            <SignedOut><SignInButton /></SignedOut>
            <SignedIn><UserButton /></SignedIn>
          </header>
          <main>{children}</main>
        </body>
      </html>
    </ClerkProvider>
  );
}
