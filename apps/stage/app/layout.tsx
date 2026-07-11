import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { Nunito } from "next/font/google";

const nunito = Nunito({ subsets: ["latin"], weight: ["700", "800", "900"] });

export const metadata: Metadata = {
  title: "Quivo — live game show, real prizes",
  description:
    "A live game show for crypto events. The room plays on their phones; winners are paid on-chain, instantly, provably fair.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        className={nunito.className}
        style={{
          margin: 0,
          background: "linear-gradient(180deg,#aca5c6 0%,#9c94b8 100%)",
          backgroundAttachment: "fixed",
          color: "#161d33",
          minHeight: "100vh",
          WebkitFontSmoothing: "antialiased",
        }}
      >
        {children}
      </body>
    </html>
  );
}
