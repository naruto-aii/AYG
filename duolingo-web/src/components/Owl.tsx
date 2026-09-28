export function Owl({
  mood = 'idle',
  size = 160,
}: {
  mood?: 'idle' | 'happy' | 'sad' | 'wow'
  size?: number
}) {
  const sad = mood === 'sad'
  const happy = mood === 'happy' || mood === 'wow'
  return (
    <svg className={`owl mood-${mood}`} width={size} height={size} viewBox="0 0 160 160" aria-hidden="true">
      <ellipse cx="80" cy="148" rx="36" ry="8" fill="#000" opacity="0.08" />
      <ellipse cx="46" cy="92" rx="18" ry="24" fill="#46a302" />
      <ellipse cx="114" cy="92" rx="18" ry="24" fill="#46a302" />
      <ellipse cx="80" cy="86" rx="48" ry="46" fill="#58cc02" />
      <ellipse cx="80" cy="98" rx="32" ry="28" fill="#b8f26d" />
      <ellipse cx="58" cy="78" rx="18" ry="20" fill="#fff" />
      <ellipse cx="102" cy="78" rx="18" ry="20" fill="#fff" />
      {happy ? (
        <>
          <path d="M48 80c6 8 14 8 20 0" fill="none" stroke="#4b4b4b" strokeWidth="4" strokeLinecap="round" />
          <path d="M92 80c6 8 14 8 20 0" fill="none" stroke="#4b4b4b" strokeWidth="4" strokeLinecap="round" />
        </>
      ) : (
        <>
          <circle className="pupil" cx={sad ? 54 : 60} cy={sad ? 82 : 80} r="6" fill="#4b4b4b" />
          <circle className="pupil" cx={sad ? 98 : 104} cy={sad ? 82 : 80} r="6" fill="#4b4b4b" />
        </>
      )}
      <path d="M72 96h16l-8 12z" fill="#ff9600" />
      {mood === 'sad' ? (
        <path d="M68 118c8-6 16-6 24 0" fill="none" stroke="#3f8f00" strokeWidth="4" strokeLinecap="round" />
      ) : (
        <path d="M66 114c8 8 20 8 28 0" fill="none" stroke="#3f8f00" strokeWidth="4" strokeLinecap="round" />
      )}
      <path d="M48 48c8-16 16-16 18-4" fill="none" stroke="#58a700" strokeWidth="6" strokeLinecap="round" />
      <path d="M112 48c-8-16-16-16-18-4" fill="none" stroke="#58a700" strokeWidth="6" strokeLinecap="round" />
    </svg>
  )
}

export function Wordmark() {
  return (
    <span className="wordmark">
      <Owl size={36} />
      <span>duolingo</span>
    </span>
  )
}
