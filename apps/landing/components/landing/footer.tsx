import Image from "next/image";
import { APK_URL } from "@/lib/links";

export function Footer() {
  return (
    <footer className="border-t-2 border-border bg-secondary-background px-5 py-10 sm:px-8">
      <div className="mx-auto flex max-w-(--spacing-container) flex-col items-center justify-between gap-6 sm:flex-row">
        <div className="flex items-center gap-2.5">
          <Image src="/logo.png" alt="Quivo" width={42} height={42} className="rounded-base border-2 border-border" />
          <span className="font-display font-heading">QUIVO</span>
        </div>

        <p className="text-center text-sm font-base text-foreground/70">
          Built for Solana Blitz v6 — MagicBlock × Solana Mobile.
        </p>

        <nav className="flex items-center gap-5 text-sm font-heading">
          <a href={APK_URL} className="underline decoration-2 underline-offset-4 hover:text-main">
            APK
          </a>
          <a
            href="https://explorer.solana.com/address/BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG?cluster=devnet"
            target="_blank"
            rel="noreferrer"
            className="underline decoration-2 underline-offset-4 hover:text-main"
          >
            Program
          </a>
          <a
            href="https://youtu.be/oTDprAI4UXk"
            target="_blank"
            rel="noreferrer"
            className="underline decoration-2 underline-offset-4 hover:text-main"
          >
            Demo
          </a>
          <a
            href="https://quivo-stage.vercel.app"
            className="underline decoration-2 underline-offset-4 hover:text-main"
          >
            Host
          </a>
        </nav>
      </div>
    </footer>
  );
}
