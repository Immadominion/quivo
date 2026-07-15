"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import confetti from "canvas-confetti";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { APK_URL } from "@/lib/links";

function burst() {
  confetti({
    particleCount: 90,
    spread: 70,
    startVelocity: 45,
    origin: { y: 0.7 },
    colors: ["#7c3aed", "#e93d82", "#f59e0b", "#22c55e", "#3b82f6"],
  });
}

export function Hero() {
  return (
    <section className="relative overflow-hidden px-5 pt-14 pb-20 sm:px-8 sm:pt-20">
      {/* halftone dot field, pure decoration */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 opacity-[0.35]"
        style={{
          backgroundImage: "radial-gradient(var(--border) 1.5px, transparent 1.5px)",
          backgroundSize: "18px 18px",
          maskImage: "radial-gradient(ellipse 60% 50% at 50% 0%, black 40%, transparent 75%)",
        }}
      />

      <div className="mx-auto grid max-w-(--spacing-container) items-center gap-12 lg:grid-cols-[1.1fr_0.9fr]">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease: "easeOut" }}
        >
          <Badge className="mb-5 bg-secondary-background text-foreground">
            ⚡ Built for Solana Blitz v6 · MagicBlock
          </Badge>

          <h1 className="text-5xl leading-[1.05] tracking-tight sm:text-6xl lg:text-7xl">
            Kahoot where the
            <span className="relative mx-3 inline-block whitespace-nowrap text-main">
              prize is real
              <svg
                aria-hidden
                viewBox="0 0 300 20"
                className="absolute -bottom-2 left-0 w-full text-magenta"
              >
                <path d="M2 15 Q150 2 298 15" stroke="currentColor" strokeWidth="6" fill="none" strokeLinecap="round" />
              </svg>
            </span>
            .
          </h1>

          <p className="mt-6 max-w-xl text-lg font-base text-foreground/80 sm:text-xl">
            Host a live trivia game show. The room joins by scanning a QR. Every answer is
            recorded on-chain, live. Winners get paid a real crypto prize the second the game
            ends, provably fair. Don&apos;t trust us, read the accounts.
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-4">
            <Button asChild size="lg" onClick={burst} className="text-base">
              <a href={APK_URL}>
                ⬇ Download the app
              </a>
            </Button>
            <Button asChild size="lg" variant="neutral" className="text-base">
              <a href="https://quivo-stage.vercel.app">▶ Host a game</a>
            </Button>
          </div>

          <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm font-heading text-foreground/70">
            <span className="flex items-center gap-2">
              <span className="size-2.5 rounded-full bg-chart-4" /> Android arm64 · 42MB · v0.1.0
            </span>
            <span className="flex items-center gap-2">
              <span className="size-2.5 rounded-full bg-chart-3" /> no wallet needed to join
            </span>
            <a
              href="https://youtu.be/oTDprAI4UXk"
              target="_blank"
              rel="noreferrer"
              className="underline decoration-2 underline-offset-4 hover:text-main"
            >
              watch the demo ↗
            </a>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.92, rotate: -6 }}
          animate={{ opacity: 1, scale: 1, rotate: -3 }}
          transition={{ duration: 0.6, ease: "easeOut", delay: 0.15 }}
          className="relative mx-auto w-full max-w-md"
        >
          <div className="rounded-base border-2 border-border bg-secondary-background p-2 shadow-shadow">
            <Image
              src="/shots/stage-podium.png"
              alt="Quivo live podium — winners paid on-chain"
              width={900}
              height={620}
              className="rounded-[8px]"
              priority
            />
          </div>
          <motion.div
            initial={{ opacity: 0, y: 10, rotate: 8 }}
            animate={{ opacity: 1, y: 0, rotate: 8 }}
            transition={{ duration: 0.5, delay: 0.5 }}
            className="absolute -right-6 -top-6 rounded-base border-2 border-border bg-chart-4 px-4 py-2 font-heading text-white shadow-shadow"
          >
            PAID ON-CHAIN ✓
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
