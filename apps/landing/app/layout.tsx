import type { Metadata, Viewport } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./globals.css";

const mono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["500", "700", "800"],
  variable: "--font-jetbrains-mono",
});

export const metadata: Metadata = {
  title: "Quivo — live game show, real prizes, paid on-chain",
  description:
    "Kahoot where the prize is real. Host a live trivia game show, the room joins by scanning a QR, winners get paid a real crypto prize on-chain the instant the game ends.",
  metadataBase: new URL("https://usequivo.fun"),
  openGraph: {
    title: "Quivo — live game show, real prizes, paid on-chain",
    description:
      "Host a live trivia game show. The room plays on their phones. Winners are paid on-chain, instantly, provably fair.",
    url: "https://usequivo.fun",
    siteName: "Quivo",
    images: ["/og.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Quivo — live game show, real prizes, paid on-chain",
    description:
      "Host a live trivia game show. The room plays on their phones. Winners are paid on-chain, instantly, provably fair.",
    images: ["/og.png"],
  },
};

export const viewport: Viewport = { width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={mono.variable}>
      <head>
        <link rel="preconnect" href="https://api.fontshare.com" />
        <link
          href="https://api.fontshare.com/v2/css?f[]=clash-display@600,700&f[]=satoshi@400,500,700,900&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased overflow-x-hidden">{children}</body>
    </html>
  );
}
