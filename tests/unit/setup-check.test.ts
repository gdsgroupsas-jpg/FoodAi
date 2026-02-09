import { describe, it, expect } from 'vitest';

describe('Setup Check', () => {
  it('vitest funziona correttamente', () => {
    expect(1 + 1).toBe(2);
  });

  it('environment jsdom e attivo', () => {
    expect(typeof document).toBe('object');
    expect(typeof window).toBe('object');
  });

  it('import alias @ funziona', async () => {
    const { cn } = await import('@/lib/utils');
    expect(typeof cn).toBe('function');
  });

  it('cn() concatena classi correttamente', async () => {
    const { cn } = await import('@/lib/utils');
    expect(cn('foo', 'bar')).toBe('foo bar');
    expect(cn('foo', false && 'bar', 'baz')).toBe('foo baz');
  });
});
