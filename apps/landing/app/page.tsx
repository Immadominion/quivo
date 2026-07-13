import { Nav } from "@/components/landing/nav";
import { Hero } from "@/components/landing/hero";
import { HowItWorks } from "@/components/landing/how-it-works";
import { AnswerGrid } from "@/components/landing/answer-grid";
import { Proof } from "@/components/landing/proof";
import { Ticker } from "@/components/landing/ticker";
import { Cta } from "@/components/landing/cta";
import { Footer } from "@/components/landing/footer";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Ticker />
        <HowItWorks />
        <AnswerGrid />
        <Proof />
        <Cta />
      </main>
      <Footer />
    </>
  );
}
