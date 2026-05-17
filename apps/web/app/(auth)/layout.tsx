// Layout des pages auth (#169). Pas de sidebar — un layout centré
// minimal style hero-form.
//
// Le route group `(auth)` ne crée pas de segment d'URL → les pages
// sont à /sign-in, /sign-up directement.
import type { ReactNode } from 'react';
import Link from 'next/link';

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-piloo-background p-6">
      <Link href="/" className="font-display text-3xl mb-8">
        <span className="text-piloo-primary">pil</span>
        <span className="text-piloo-accent">oo</span>
      </Link>
      <main className="w-full max-w-md">{children}</main>
    </div>
  );
}
