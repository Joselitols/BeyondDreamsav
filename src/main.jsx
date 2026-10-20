import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import Mutirao from './Mutirao'

const path = window.location.pathname.toLowerCase()
const Page = path.startsWith('/autismo') || path.startsWith('/mutirao') ? Mutirao : App

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <Page />
  </React.StrictMode>,
)
