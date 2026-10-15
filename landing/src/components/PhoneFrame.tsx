import Image from 'next/image';

type Props = {
  name: string;
  alt: string;
  caption?: string;
  priority?: boolean;
  className?: string;
  sizes?: string;
  /** Подпись над телефоном (внутри панели с обрезкой снизу). */
  captionFirst?: boolean;
};

/** Реальный скриншот приложения в простой рамке телефона. Файлы лежат в public/screens. */
export function PhoneFrame({ name, alt, caption, priority, className, sizes, captionFirst }: Props) {
  const frame = (
    <div className={`phone ${className ?? ''}`}>
      <Image
        src={`/screens/${name}.webp`}
        alt={alt}
        width={828}
        height={1799}
        priority={priority}
        sizes={sizes ?? '(max-width: 720px) 45vw, 300px'}
      />
    </div>
  );
  if (!caption) return frame;
  return (
    <figure className="phone-wrap" style={{ margin: 0 }}>
      {captionFirst && <figcaption>{caption}</figcaption>}
      {frame}
      {!captionFirst && <figcaption>{caption}</figcaption>}
    </figure>
  );
}
