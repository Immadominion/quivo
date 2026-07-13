"use client";

import Image from "next/image";
import { motion } from "framer-motion";

const SHOTS = [
  { src: "/shots/stage-lobby.png", alt: "Live lobby — players join by QR", rotate: -2 },
  { src: "/shots/stage-question.png", alt: "Live question on the big screen", rotate: 2 },
  { src: "/shots/stage-idle.png", alt: "Host screen — create a game, set the pot", rotate: -1.5 },
];

export function Proof() {
  return (
    <section className="border-t-2 border-border px-5 py-20 sm:px-8">
      <div className="mx-auto max-w-(--spacing-container)">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <h2 className="text-4xl sm:text-5xl">This is a real, working game</h2>
          <a
            href="https://explorer.solana.com/address/BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG?cluster=devnet"
            target="_blank"
            rel="noreferrer"
            className="font-heading underline decoration-2 underline-offset-4 hover:text-main"
          >
            Read the on-chain program ↗
          </a>
        </div>

        <div className="mt-14 grid gap-10 sm:grid-cols-3">
          {SHOTS.map((s, i) => (
            <motion.div
              key={s.src}
              initial={{ opacity: 0, y: 30, rotate: 0 }}
              whileInView={{ opacity: 1, y: 0, rotate: s.rotate }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              whileHover={{ rotate: 0, scale: 1.03 }}
              className="rounded-base border-2 border-border bg-secondary-background p-2 shadow-shadow"
            >
              <Image src={s.src} alt={s.alt} width={640} height={440} className="rounded-[8px]" />
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
