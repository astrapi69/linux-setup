import asyncio
import json
from dbus_next.aio import MessageBus
from dbus_next import BusType

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

    async def fix(self, fix_id: str):
        reply = await self.iface.call_fix(fix_id)
        return json.loads(reply)