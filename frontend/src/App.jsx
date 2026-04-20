import { useState } from 'react'
import { useAccount } from 'wagmi'
import ConnectButton from './components/ConnectButton.jsx'
import BalancePanel from './components/BalancePanel.jsx'
import DepositWithdraw from './components/DepositWithdraw.jsx'
import CreateTask from './components/CreateTask.jsx'
import TaskList from './components/TaskList.jsx'

function App() {
  const { isConnected } = useAccount()
  const [taskRefreshKey, setTaskRefreshKey] = useState(0)

  return (
    <div className="app">
      <header className="header">
        <div className="logo">StudyStake</div>
        <ConnectButton />
      </header>

      {!isConnected ? (
        <div className="welcome">
          <h1>自律质押协议</h1>
          <p>存入 USDC → 设定目标 → 按时签到 → 保留资金</p>
          <p className="sub-hint">支持 Click 点击签到 · NFC 防作弊签到</p>
        </div>
      ) : (
        <main className="main-grid">
          <section className="col-left">
            <BalancePanel />
            <DepositWithdraw />
            <CreateTask onTaskCreated={() => setTaskRefreshKey(k => k + 1)} />
          </section>

          <section className="col-right">
            <TaskList refreshTrigger={taskRefreshKey} />
          </section>
        </main>
      )}

      <footer className="footer">
        <p>StudyStake v1 · UUPS Proxy · Sepolia Testnet</p>
        <p>0x191c…78d77C</p>
      </footer>
    </div>
  )
}

export default App
