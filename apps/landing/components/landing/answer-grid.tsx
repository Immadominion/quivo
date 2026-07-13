"use client";

import { motion } from "framer-motion";

const ANSWERS = [
  { glyph: "▲", label: "Fast", color: "bg-chart-1" },
  { glyph: "◆", label: "Fair", color: "bg-chart-2" },
  { glyph: "●", label: "Onchain", color: "bg-chart-3" },
  { glyph: "■", label: "Real prizes", color: "bg-chart-4" },
];

export function AnswerGrid() {
  return (
    <section className="px-5 py-16 sm:px-8">
      <div className="mx-auto max-w-(--spacing-container) text-center">
        <p className="mb-8 font-heading text-sm uppercase tracking-[0.2em] text-foreground/60">
          the four-color grammar every player already knows
        </p>
        <div className="mx-auto grid max-w-2xl grid-cols-2 gap-4 sm:grid-cols-4">
          {ANSWERS.map((a, i) => (
            <motion.div
              key={a.label}
              initial={{ opacity: 0, scale: 0.85 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.35, delay: i * 0.06, type: "spring", stiffness: 260, damping: 18 }}
              whileHover={{ y: -4 }}
              className={`flex flex-col items-center justify-center gap-2 rounded-base border-2 border-border ${a.color} px-4 py-8 shadow-shadow`}
            >
              <span className="text-4xl text-white/90">{a.glyph}</span>
              <span className="font-heading text-white">{a.label}</span>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
