import Image from "next/image";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { APK_URL } from "@/lib/links";

export function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b-2 border-border bg-background/90 backdrop-blur">
      <div className="mx-auto flex max-w-(--spacing-container) items-center justify-between px-5 py-3 sm:px-8">
        <Link href="/" className="flex items-center gap-2.5">
          <Image
            src="/logo.png"
            alt="Quivo"
            width={54}
            height={54}
            className="rounded-base border-2 border-border shadow-shadow"
          />
          <span className="font-display text-xl font-heading tracking-tight">QUIVO</span>
        </Link>
        <div className="flex items-center gap-3">
          <a
            href="https://quivo-stage.vercel.app"
            className="hidden text-sm font-heading underline decoration-2 underline-offset-4 hover:text-main sm:inline"
          >
            Host a game
          </a>
          <Button asChild size="sm">
            <a href={APK_URL}>
              ⬇ Get the app
            </a>
          </Button>
        </div>
      </div>
    </header>
  );
}
