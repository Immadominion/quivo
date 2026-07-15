"use client";

import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { APK_URL } from "@/lib/links";

export function Cta() {
  return (
    <section className="px-5 py-24 sm:px-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.5 }}
        className="relative mx-auto max-w-4xl overflow-hidden rounded-base border-2 border-border bg-main px-8 py-16 text-center shadow-shadow sm:px-16"
      >
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-[0.15]"
          style={{
            backgroundImage: "radial-gradient(#fff 1.5px, transparent 1.5px)",
            backgroundSize: "16px 16px",
          }}
        />
        <h2 className="relative text-4xl text-white sm:text-5xl">
          Run one live tonight.
        </h2>
        <p className="relative mx-auto mt-4 max-w-lg text-lg font-base text-white/85">
          Free to play on devnet. The room joins in seconds. The payout is the part they&apos;ll
          talk about after.
        </p>
        <div className="relative mt-8 flex flex-wrap items-center justify-center gap-4">
          <Button asChild size="lg" variant="neutral" className="text-base">
            <a href={APK_URL}>
              ⬇ Download the app
            </a>
          </Button>
          <Button asChild size="lg" variant="reverse" className="border-white bg-transparent text-base text-white">
            <a href="https://quivo-stage.vercel.app">▶ Host a game</a>
          </Button>
        </div>
        <p className="relative mt-5 text-xs font-base text-white/60">
          Android APK, sideloaded — allow installs from unknown sources when prompted.
        </p>
      </motion.div>
    </section>
  );
}
