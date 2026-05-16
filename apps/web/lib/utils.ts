// Helper standard shadcn — combine clsx + tailwind-merge.
//   <div className={cn('p-4', condition && 'bg-primary', className)} />
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
