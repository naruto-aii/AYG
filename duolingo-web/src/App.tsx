import { Navigate, Route, Routes, useParams } from 'react-router-dom'
import { AuthPage } from './pages/Auth'
import { CompletePage } from './pages/Complete'
import { GuidebookPage } from './pages/Guidebook'
import { LandingPage } from './pages/Landing'
import { LeaderboardPage } from './pages/Leaderboard'
import { LearnPage } from './pages/Learn'
import { LessonPage } from './pages/Lesson'
import { OnboardingPage } from './pages/Onboarding'
import { PracticePage } from './pages/Practice'
import { ProfilePage } from './pages/Profile'
import { QuestsPage } from './pages/Quests'
import { SettingsPage } from './pages/Settings'
import { ShopPage } from './pages/Shop'
import { SuperPage } from './pages/Super'

function LessonRoute({ practice = false }: { practice?: boolean }) {
  const { nodeId } = useParams()
  return <LessonPage key={`${practice ? 'practice' : 'lesson'}-${nodeId}`} practice={practice} />
}

export function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<AuthPage mode="login" />} />
      <Route path="/register" element={<AuthPage mode="register" />} />
      <Route path="/onboarding" element={<OnboardingPage />} />
      <Route path="/learn" element={<LearnPage />} />
      <Route path="/lesson/:nodeId" element={<LessonRoute />} />
      <Route path="/practice/:nodeId" element={<LessonRoute practice />} />
      <Route path="/complete" element={<CompletePage />} />
      <Route path="/practice" element={<PracticePage />} />
      <Route path="/leaderboard" element={<LeaderboardPage />} />
      <Route path="/quests" element={<QuestsPage />} />
      <Route path="/shop" element={<ShopPage />} />
      <Route path="/profile" element={<ProfilePage />} />
      <Route path="/profile/:userId" element={<ProfilePage />} />
      <Route path="/settings" element={<SettingsPage />} />
      <Route path="/super" element={<SuperPage />} />
      <Route path="/guidebook/:unitId" element={<GuidebookPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
