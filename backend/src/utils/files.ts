const HEIC_BRANDS = new Set(['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1']);

/// Phones often send no file type, so the first bytes of the file decide it
export function detectFileType(file: Buffer): { ext: string; mime: string } | null {
  if (file.length < 12) return null;
  if (file[0] === 0xff && file[1] === 0xd8 && file[2] === 0xff) return { ext: '.jpg', mime: 'image/jpeg' };
  if (file.subarray(0, 8).toString('hex') === '89504e470d0a1a0a') return { ext: '.png', mime: 'image/png' };
  if (file.subarray(0, 4).toString() === 'RIFF' && file.subarray(8, 12).toString() === 'WEBP') return { ext: '.webp', mime: 'image/webp' };
  // Videos carry the same "ftyp" mark, so the brand after it must be an image one
  if (file.subarray(4, 8).toString() === 'ftyp' && HEIC_BRANDS.has(file.subarray(8, 12).toString())) return { ext: '.heic', mime: 'image/heic' };
  if (file.subarray(0, 5).toString() === '%PDF-') return { ext: '.pdf', mime: 'application/pdf' };
  return null;
}
