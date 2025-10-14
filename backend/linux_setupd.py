#!/usr/bin/env python3
import asyncio
import json
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method
from dbus_next import BusType
from linux_setup_backend import run_provision, get_latest

SERVICE = "org.astrapi.LinuxSetup1"
OBJ_PATH = "/org/astrapi/LinuxSetup1"
IFACE = "org.astrapi.LinuxSetup1"
VERSION = "0.1.0"

class LinuxSetupService(ServiceInterface):
    def __init__(self):
        super().__init__(IFACE)

    @method()
    def Version(self) -> 's':
        return VERSION

    @method()
    def Audit(self, profile: 's', quick: 'b') -> 's':
        ok, meta = run_provision("audit", profile=profile, quick=bool(quick))
        return json.dumps(meta)

    @method()
    def Harden(self, profile: 's') -> 's':
        ok, meta = run_provision("harden", profile=profile)
        return json.dumps(meta)

    @method()
    def GetLatest(self) -> 's':
        return json.dumps(get_latest())

async def main():
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    service = LinuxSetupService()
    bus.export(OBJ_PATH, service)  # ✅ ONLY 2 ARGS
    await bus.request_name(SERVICE)
    print(f"✅ {SERVICE} ready on {OBJ_PATH}")
    await asyncio.Event().wait()

if __name__ == '__main__':
    asyncio.run(main())