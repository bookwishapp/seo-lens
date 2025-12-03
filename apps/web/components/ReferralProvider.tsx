'use client'

import React, { createContext, useContext, useEffect, useState } from 'react'

interface ReferralContextType {
  referralCode: string | null
  getAppUrl: (path?: string) => string
}

const ReferralContext = createContext<ReferralContextType>({
  referralCode: null,
  getAppUrl: (path = '') => `/app${path}`,
})

export function useReferral() {
  return useContext(ReferralContext)
}

const REFERRAL_STORAGE_KEY = 'seo_lens_referral_code'

interface ReferralProviderProps {
  children: React.ReactNode
}

export function ReferralProvider({ children }: ReferralProviderProps) {
  const [referralCode, setReferralCode] = useState<string | null>(null)

  useEffect(() => {
    // Check URL for ref param
    const urlParams = new URLSearchParams(window.location.search)
    const refFromUrl = urlParams.get('ref')

    if (refFromUrl) {
      // Store in localStorage for persistence
      localStorage.setItem(REFERRAL_STORAGE_KEY, refFromUrl)
      setReferralCode(refFromUrl)
    } else {
      // Check localStorage for previously stored code
      const storedRef = localStorage.getItem(REFERRAL_STORAGE_KEY)
      if (storedRef) {
        setReferralCode(storedRef)
      }
    }
  }, [])

  // Helper to build app URLs with ref param
  const getAppUrl = (path: string = '') => {
    const baseUrl = `/app${path}`
    if (referralCode) {
      const separator = baseUrl.includes('?') ? '&' : '?'
      return `${baseUrl}${separator}ref=${referralCode}`
    }
    return baseUrl
  }

  return (
    <ReferralContext.Provider value={{ referralCode, getAppUrl }}>
      {children}
    </ReferralContext.Provider>
  )
}
