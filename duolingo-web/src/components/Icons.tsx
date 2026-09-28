type IconName =
  | 'home'
  | 'practice'
  | 'shield'
  | 'quest'
  | 'shop'
  | 'person'
  | 'more'
  | 'flame'
  | 'gem'
  | 'heart'
  | 'book'
  | 'chest'
  | 'trophy'
  | 'star'
  | 'lock'
  | 'speaker'
  | 'close'
  | 'check'
  | 'gear'
  | 'bolt'
  | 'freeze'

export function Icon({
  name,
  size = 28,
  color = 'currentColor',
}: {
  name: IconName
  size?: number
  color?: string
}) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true" fill={color}>
      {name === 'home' && <path d="M5 14.5 16 5l11 9.5V27a2 2 0 0 1-2 2h-6v-8h-6v8H7a2 2 0 0 1-2-2V14.5Z" />}
      {name === 'practice' && (
        <path d="M8 13h4v6H8a3 3 0 0 1-3-3v0a3 3 0 0 1 3-3Zm12 0h4a3 3 0 0 1 3 3v0a3 3 0 0 1-3 3h-4v-6Zm-8 2h8v2H12v-2Z" />
      )}
      {name === 'shield' && <path d="M16 3 6 7v8c0 6.2 4.1 10.6 10 12 5.9-1.4 10-5.8 10-12V7L16 3Z" />}
      {name === 'quest' && (
        <path d="M8 5h16v4H8V5Zm0 6h16v16H8V11Zm4 4v2h8v-2h-8Zm0 4v2h5v-2h-5Z" />
      )}
      {name === 'shop' && <path d="M6 10h20l-2 16H8L6 10Zm4-4h12l2 4H8l2-4Z" />}
      {name === 'person' && (
        <>
          <circle cx="16" cy="11" r="5" />
          <path d="M6 27c1.6-5 5-7.5 10-7.5S24.4 22 26 27H6Z" />
        </>
      )}
      {name === 'more' && (
        <>
          <circle cx="7" cy="16" r="2.2" />
          <circle cx="16" cy="16" r="2.2" />
          <circle cx="25" cy="16" r="2.2" />
        </>
      )}
      {name === 'flame' && <path d="M16 3s6 6 6 12a6 6 0 0 1-12 0c0-2 1-3.5 1-3.5S10 14 10 18a6 6 0 0 0 10.8 3.6C18 18 16 14 16 14s2 2 2 5a2.5 2.5 0 0 1-5 0c0-2 3-6 3-6S12 10 16 3Z" />}
      {name === 'gem' && <path d="M8 6h16l4 7-12 14L4 13l4-7Zm2.2 2L7.2 12h6.2l-3.2-4Zm5.2 0-3.4 4h7.9l-3.3-4h-1.2Zm6.4 0-3.2 4h6.2l-3-4ZM7.6 14l8.4 10.2L24.4 14H7.6Z" />}
      {name === 'heart' && <path d="M16 27S4 19.5 4 12a6 6 0 0 1 11-3 6 6 0 0 1 11 3c0 7.5-12 15-12 15Z" />}
      {name === 'book' && <path d="M6 6.5A3.5 3.5 0 0 1 9.5 3H26v22H9.5A3.5 3.5 0 0 0 6 28.5V6.5ZM9.5 25H24V5H9.5A1.5 1.5 0 0 0 8 6.5v16.8A3.5 3.5 0 0 1 9.5 25Z" />}
      {name === 'chest' && <path d="M4 13h24v13H4V13Zm2-6h20v6H6V7Zm8 10h4v5h-4v-5Z" />}
      {name === 'trophy' && <path d="M9 4h14v8a7 7 0 0 1-14 0V4ZM7 6H4v3a4 4 0 0 0 4 4V6Zm18 0v7a4 4 0 0 0 4-4V6h-4ZM12 20h8v3h-8v-3Zm-2 5h12v3H10v-3Z" />}
      {name === 'star' && <path d="m16 3 3.7 7.6 8.3 1.2-6 5.8 1.4 8.3L16 22.2 8.6 25.9 10 17.6 4 11.8l8.3-1.2L16 3Z" />}
      {name === 'lock' && <path d="M10 14V10a6 6 0 0 1 12 0v4h2v14H8V14h2Zm2 0h8v-4a4 4 0 0 0-8 0v4Z" />}
      {name === 'speaker' && <path d="M6 12h5l7-5v18l-7-5H6V12Zm14.2.2a6 6 0 0 1 0 7.6l-1.6-1.2a4 4 0 0 0 0-5.2l1.6-1.2Zm3.2-2.6a10 10 0 0 1 0 12.8l-1.6-1.2a8 8 0 0 0 0-10.4l1.6-1.2Z" />}
      {name === 'close' && <path d="m8.2 6.8 7.8 7.8 7.8-7.8 1.4 1.4L17.4 16l7.8 7.8-1.4 1.4-7.8-7.8-7.8 7.8-1.4-1.4L14.6 16 6.8 8.2l1.4-1.4Z" />}
      {name === 'check' && <path d="m6 16.5 6.2 6.2L26 9l1.6 1.6L12.2 26 4.4 18.1 6 16.5Z" />}
      {name === 'gear' && <path d="M13 3h6l.7 3.2a8.8 8.8 0 0 1 2.4 1.4l3.1-1.2 3 5.2-2.6 2.2a9 9 0 0 1 0 2.4l2.6 2.2-3 5.2-3.1-1.2a8.8 8.8 0 0 1-2.4 1.4L19 29h-6l-.7-3.2a8.8 8.8 0 0 1-2.4-1.4l-3.1 1.2-3-5.2 2.6-2.2a9 9 0 0 1 0-2.4L3.8 11.6l3-5.2 3.1 1.2a8.8 8.8 0 0 1 2.4-1.4L13 3Zm3 8a5 5 0 1 0 0 10 5 5 0 0 0 0-10Z" />}
      {name === 'bolt' && <path d="M18 2 6 18h8l-2 12 14-18h-8l0-10Z" />}
      {name === 'freeze' && <path d="M15 2h2v6l4-2 1 1.7-4.2 2.1 4.2 2.2-1 1.7-4-2v4.3l4.6 2.6 1-1.7 1.7 1-1 1.8-5.3-3v5.3l4.2 2.2-1 1.7L17 24v6h-2v-6l-4 2-1-1.7 4.2-2.1L10 20.1l1-1.7 4 2V16l-4.6-2.6-1 1.7-1.7-1 1-1.8 5.3 3V9.9L9.8 7.7l1-1.7L15 8V2Z" />}
    </svg>
  )
}
