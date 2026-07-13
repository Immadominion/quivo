"use client";

import { motion } from "framer-motion";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const STEPS = [
  {
    n: "01",
    color: "bg-chart-1",
    title: "Escrow the pot",
    body: "The host sets a prize pool. It's escrowed on-chain before a single question is asked — nothing to fake after the fact.",
  },
  {
    n: "02",
    color: "bg-chart-2",
    title: "Room scans a QR",
    body: "Players join on their phones in seconds. An ephemeral Solana wallet is minted silently — no app, no signup, no seed phrase.",
  },
  {
    n: "03",
    color: "bg-chart-3",
    title: "Every answer, anchored",
    body: "Answers are committed live through MagicBlock's Ephemeral Rollups — fast enough to feel instant, verifiable on-chain.",
  },
  {
    n: "04",
    color: "bg-chart-4",
    title: "Winners paid, instantly",
    body: "The moment the game ends, winners are settled on-chain, in front of the room. Tap the tx, watch it land.",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="border-t-2 border-border bg-secondary-background px-5 py-20 sm:px-8">
      <div className="mx-auto max-w-(--spacing-container)">
        <h2 className="max-w-xl text-4xl sm:text-5xl">How a Quivo night works</h2>

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <motion.div
              key={s.n}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{ duration: 0.4, delay: i * 0.08 }}
            >
              <Card className="h-full bg-background">
                <CardHeader>
                  <span
                    className={`mb-3 flex size-10 items-center justify-center rounded-base border-2 border-border font-mono text-sm font-heading text-white ${s.color}`}
                  >
                    {s.n}
                  </span>
                  <CardTitle className="text-xl">{s.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-sm font-base text-foreground/75">{s.body}</p>
                </CardContent>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
