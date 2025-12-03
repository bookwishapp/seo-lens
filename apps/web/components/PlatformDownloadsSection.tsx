'use client'

import React from 'react'
import { Apple, Globe, Download, ArrowRight } from 'lucide-react'

// Android robot icon
function AndroidIcon({ size }: { size: number }): React.JSX.Element {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="#5F9DF7">
      <path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85a.637.637 0 0 0-.83.22l-1.88 3.24a11.46 11.46 0 0 0-8.94 0L5.65 5.67a.643.643 0 0 0-.87-.2c-.28.18-.37.54-.22.83L6.4 9.48A10.78 10.78 0 0 0 1 18h22a10.78 10.78 0 0 0-5.4-8.52M7 15.25a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5m10 0a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5"/>
    </svg>
  )
}

export function PlatformDownloadsSection(): React.JSX.Element {
  const handleWebStart = (): void => {
    window.location.href = '/app'
  }

  return (
    <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
      <div className="bg-white border border-gray-200 rounded-2xl p-6 sm:p-8">
        <h2 className="text-2xl font-bold text-gray-900 text-center mb-8">
          Get Started on Your Platform
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <PlatformColumn
            icon={<Apple size={48} color="#5F9DF7" />}
            name="iOS"
            status="Coming soon"
            actionIcon={<Download size={24} color="#9CA3AF" />}
            actionTooltip="Coming Soon"
            onAction={() => {}}
            disabled
          />

          <PlatformColumn
            icon={<AndroidIcon size={48} />}
            name="Android"
            status="Coming soon"
            actionIcon={<Download size={24} color="#9CA3AF" />}
            actionTooltip="Coming Soon"
            onAction={() => {}}
            disabled
          />

          <PlatformColumn
            icon={<Globe size={48} color="#5F9DF7" />}
            name="Web"
            status="Launch app now"
            actionIcon={<ArrowRight size={24} color="#5F9DF7" />}
            actionTooltip="Launch App"
            onAction={handleWebStart}
          />
        </div>
      </div>
    </section>
  )
}

interface PlatformColumnProps {
  icon: React.ReactNode
  name: string
  status: string | React.ReactNode
  actionIcon: React.ReactNode
  actionTooltip: string
  onAction: () => void
  disabled?: boolean
}

function PlatformColumn({
  icon,
  name,
  status,
  actionIcon,
  actionTooltip,
  onAction,
  disabled = false,
}: PlatformColumnProps): React.JSX.Element {
  return (
    <div className="flex flex-col items-center text-center space-y-4">
      {icon}
      <div>
        <div className="text-lg font-semibold text-gray-900">{name}</div>
        <div className="text-sm text-gray-600 mt-1">{status}</div>
      </div>
      <button
        onClick={disabled ? undefined : onAction}
        title={actionTooltip}
        disabled={disabled}
        className={`p-3 rounded-full transition-colors ${
          disabled
            ? 'cursor-not-allowed bg-gray-100'
            : 'cursor-pointer bg-primary/10 hover:bg-primary/20'
        }`}
      >
        {actionIcon}
      </button>
    </div>
  )
}
