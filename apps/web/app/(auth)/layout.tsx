// Layout des pages auth (#169). Pas de sidebar — un layout centré
// minimal style hero-form.
//
// Le route group `(auth)` ne crée pas de segment d'URL → les pages
// sont à /sign-in, /sign-up directement.
import type { ReactNode } from 'react';
import Image from 'next/image';
import Link from 'next/link';

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-piloo-background p-6">
      <Link href="/" className="mb-8 flex items-center gap-3">
        <Image src="/logo-piloo.png" alt="" width={44} height={44} />
        <span className="font-display text-3xl font-semibold text-foreground">Piloo</span>
      </Link>
      <main className="w-full max-w-md">{children}</main>
    </div>
  );
}
