#!/usr/bin/env python3
import json, sys, asyncio
from PySide6 import QtWidgets, QtCore
from dbus_next.aio import MessageBus
from dbus_next import BusType

SERVICE  = "org.astrapi.LinuxSetup1"
OBJ_PATH = "/org/astrapi/LinuxSetup1"
IFACE    = "org.astrapi.LinuxSetup1"

class BackendClient(QtCore.QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.bus = None
        self.proxy = None
        self.obj = None
        self.iface = None

    async def connect(self):
        self.bus = await MessageBus(bus_type=BusType.SESSION).connect()
        self.obj = await self.bus.introspect(SERVICE, OBJ_PATH)
        self.proxy = self.bus.get_proxy_object(SERVICE, OBJ_PATH, self.obj)
        self.iface = self.proxy.get_interface(IFACE)

    async def get_latest(self):
        reply = await self.iface.call_get_latest()
        return json.loads(reply)

    async def audit(self, profile="desktop", quick=True):
        reply = await self.iface.call_audit(profile, quick)
        return json.loads(reply)

    async def harden(self, profile="desktop"):
        reply = await self.iface.call_harden(profile)
        return json.loads(reply)

class MainWindow(QtWidgets.QWidget):
    def __init__(self, client: BackendClient):
        super().__init__()
        self.client = client
        self.setWindowTitle("Linux Setup – Security")
        self.resize(720, 520)

        self.text = QtWidgets.QPlainTextEdit(readOnly=True)
        btn_refresh = QtWidgets.QPushButton("Refresh (Latest)")
        btn_audit   = QtWidgets.QPushButton("Run Audit (Quick)")
        btn_harden  = QtWidgets.QPushButton("Apply Harden (Desktop)")

        btn_refresh.clicked.connect(lambda: asyncio.create_task(self.refresh()))
        btn_audit.clicked.connect(lambda: asyncio.create_task(self.run_audit()))
        btn_harden.clicked.connect(lambda: asyncio.create_task(self.run_harden()))

        lay = QtWidgets.QVBoxLayout(self)
        lay.addWidget(self.text)
        row = QtWidgets.QHBoxLayout()
        row.addWidget(btn_refresh); row.addWidget(btn_audit); row.addWidget(btn_harden)
        lay.addLayout(row)

        QtCore.QTimer.singleShot(300, lambda: asyncio.create_task(self.refresh()))

    async def refresh(self):
        try:
            data = await self.client.get_latest()
            self.text.setPlainText(json.dumps(data, indent=2))
        except Exception as e:
            self.text.setPlainText(f"Error: {e}")

    async def run_audit(self):
        self.text.setPlainText("Running audit…")
        data = await self.client.audit(profile="desktop", quick=True)
        self.text.setPlainText(json.dumps(data, indent=2))

    async def run_harden(self):
        self.text.setPlainText("Applying harden…")
        data = await self.client.harden(profile="desktop")
        self.text.setPlainText(json.dumps(data, indent=2))

async def main():
    app = QtWidgets.QApplication(sys.argv)
    client = BackendClient()
    await client.connect()
    w = MainWindow(client); w.show()
    # integrate asyncio with Qt
    loop = asyncio.get_running_loop()
    timer = QtCore.QTimer(); timer.timeout.connect(lambda: None); timer.start(50)
    app.lastWindowClosed.connect(loop.stop)
    await loop.run_in_executor(None, app.exec)

if __name__ == "__main__":
    asyncio.run(main())
