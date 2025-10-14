#!/usr/bin/env python3
import asyncio
import json
import sys
from PySide6 import QtWidgets, QtCore
from dbus_next.aio import MessageBus
from dbus_next import BusType
import qasync

SERVICE = "org.astrapi.LinuxSetup1"
OBJ_PATH = "/org/astrapi/LinuxSetup1"
IFACE = "org.astrapi.LinuxSetup1"


class BackendClient:
    def __init__(self):
        self.bus = None
        self.proxy_obj = None
        self.iface = None

    async def connect(self):
        self.bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
        introspection = await self.bus.introspect(SERVICE, OBJ_PATH)
        self.proxy_obj = self.bus.get_proxy_object(SERVICE, OBJ_PATH, introspection)
        self.iface = self.proxy_obj.get_interface(IFACE)

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
        self.setWindowTitle("Linux Setup – Security Dashboard")
        self.resize(720, 520)

        self.text = QtWidgets.QPlainTextEdit(readOnly=True)
        self.text.setPlaceholderText("Click a button to run an action...")

        # ✅ All three buttons
        self.btn_refresh = QtWidgets.QPushButton("Refresh (Latest)")
        self.btn_audit = QtWidgets.QPushButton("Run Audit (Quick)")
        self.btn_harden = QtWidgets.QPushButton("Apply Harden (Desktop)")

        # Connect buttons
        self.btn_refresh.clicked.connect(lambda: asyncio.create_task(self.refresh()))
        self.btn_audit.clicked.connect(lambda: asyncio.create_task(self.run_audit()))
        self.btn_harden.clicked.connect(lambda: asyncio.create_task(self.run_harden()))

        # Layout
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.text)

        button_layout = QtWidgets.QHBoxLayout()
        button_layout.addWidget(self.btn_refresh)
        button_layout.addWidget(self.btn_audit)
        button_layout.addWidget(self.btn_harden)
        layout.addLayout(button_layout)

        # Initial load
        QtCore.QTimer.singleShot(200, lambda: asyncio.create_task(self.refresh()))

    async def refresh(self):
        try:
            data = await self.client.get_latest()
            self.text.setPlainText(json.dumps(data, indent=2, ensure_ascii=False))
        except Exception as e:
            self.text.setPlainText(f"❌ Error loading latest:\n{e}")

    async def run_audit(self):
        self.text.setPlainText("Running audit (quick)...\n")
        try:
            data = await self.client.audit(profile="desktop", quick=True)
            self.text.setPlainText(json.dumps(data, indent=2, ensure_ascii=False))
        except Exception as e:
            self.text.setPlainText(f"❌ Audit failed:\n{e}")

    async def run_harden(self):
        self.text.setPlainText("Applying hardening (desktop profile)...\n")
        try:
            data = await self.client.harden(profile="desktop")
            self.text.setPlainText(json.dumps(data, indent=2, ensure_ascii=False))
        except Exception as e:
            self.text.setPlainText(f"❌ Harden failed:\n{e}")


def main():
    app = QtWidgets.QApplication(sys.argv)
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    client = BackendClient()

    async def run():
        await client.connect()
        window = MainWindow(client)
        window.show()
        while window.isVisible():
            await asyncio.sleep(0.1)

    with loop:
        loop.run_until_complete(run())


if __name__ == "__main__":
    main()