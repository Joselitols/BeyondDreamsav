import React from 'react'

// Troque estes valores antes de publicar
const WHATSAPP = '5581900000000' // DDI + DDD + número, só dígitos
const LOCAL = 'LOCAL DO MUTIRÃO'
const DATA = 'DIA E HORÁRIO'

const zap = (texto) => `https://wa.me/${WHATSAPP}?text=${encodeURIComponent(texto)}`

const card = { background: '#fff', borderRadius: 16, padding: '1.25rem', marginBottom: '1rem', boxShadow: '0 2px 8px rgba(0,0,0,.08)' }
const botao = { display: 'block', textAlign: 'center', background: '#16a34a', color: '#fff', fontSize: '1.25rem', fontWeight: 700, padding: '1rem', borderRadius: 14, textDecoration: 'none', margin: '1rem 0' }

export default function Mutirao() {
  return (
    <div style={{ background: '#eef4ff', minHeight: '100vh', fontFamily: 'Arial, sans-serif', color: '#0f172a' }}>
      <header style={{ background: '#1d4ed8', color: '#fff', padding: '2rem 1rem', textAlign: 'center' }}>
        <h1 style={{ margin: 0, fontSize: '1.9rem' }}>Mutirão do Autismo</h1>
        <p style={{ margin: '.5rem 0 0', fontSize: '1.1rem' }}>Paulista • Cadastro gratuito de famílias</p>
      </header>

      <main style={{ maxWidth: 640, margin: '0 auto', padding: '1rem' }}>
        <a style={botao} href={zap('Olá! Quero me cadastrar no Mutirão do Autismo.')}>
          Quero me cadastrar pelo WhatsApp
        </a>

        <section style={card}>
          <h2>Onde e quando</h2>
          <p><strong>Local:</strong> {LOCAL}</p>
          <p><strong>Data:</strong> {DATA}</p>
        </section>

        <section style={card}>
          <h2>O que a gente faz</h2>
          <ul style={{ lineHeight: 1.6, paddingLeft: '1.2rem' }}>
            <li><strong>BPC/LOAS:</strong> ajudamos a família a pedir o benefício e, se for negado, a buscar na Justiça.</li>
            <li><strong>Terapias pelo SUS:</strong> acompanhamos o pedido das terapias prescritas (fono, psicologia, terapia ocupacional e outras).</li>
            <li><strong>Cadastro das famílias:</strong> reunimos os pacientes com autismo para o nosso projeto.</li>
          </ul>
        </section>

        <section style={card}>
          <h2>Leve no dia</h2>
          <ul style={{ lineHeight: 1.6, paddingLeft: '1.2rem' }}>
            <li>Documento com foto do responsável e do paciente</li>
            <li>CPF e Cartão do SUS</li>
            <li>Laudo médico e receitas/prescrições de terapias</li>
            <li>CadÚnico (NIS) e comprovante de residência</li>
            <li>Comprovantes de renda da família</li>
          </ul>
        </section>

        <p style={{ fontSize: '.85rem', color: '#475569' }}>
          Este projeto oferece orientação e organização de documentos. O resultado de cada pedido depende da análise do INSS, do SUS e da Justiça.
        </p>
      </main>
    </div>
  )
}
