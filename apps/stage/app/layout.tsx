import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "Quivo — live game show, real prizes",
  description: "A live game show for crypto events. Winners paid on-chain, instantly, provably fair.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1 };

// Deliberately simple styling for now — the real design pass comes later.
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          background: "#0d0d12",
          color: "#f2f2f5",
          fontFamily: "system-ui, -apple-system, sans-serif",
          minHeight: "100vh",
        }}
      >
        {children}
      </body>
    </html>
  );
}
