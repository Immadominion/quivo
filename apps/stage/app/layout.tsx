import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { JetBrains_Mono } from "next/font/google";

const mono = JetBrains_Mono({ subsets: ["latin"], weight: ["500", "700"], variable: "--font-mono" });

export const metadata: Metadata = {
  title: "Quivo, live game show, real prizes",
  description:
    "A live game show for crypto events. The room plays on their phones; winners are paid on-chain, instantly, provably fair.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://api.fontshare.com" />
        <link
          href="https://api.fontshare.com/v2/css?f[]=clash-display@600,700&f[]=satoshi@400,500,700,900&display=swap"
          rel="stylesheet"
        />
      </head>
      <body
        className={mono.variable}
        style={{
          margin: 0,
          fontFamily: "'Satoshi', system-ui, sans-serif",
          background: "linear-gradient(180deg,#ffffff 0%,#f6f1fe 100%)",
          backgroundAttachment: "fixed",
          color: "#17122a",
          minHeight: "100vh",
          WebkitFontSmoothing: "antialiased",
        }}
      >
        {children}
      </body>
    </html>
  );
}
