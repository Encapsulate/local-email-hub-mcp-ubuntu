import asyncio
import json

from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client


async def main() -> None:
    async with streamable_http_client("http://127.0.0.1:18477/mcp") as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            health = await session.call_tool("email_health", {})
            print(json.dumps({
                "tools": [tool.name for tool in tools.tools],
                "health_is_error": health.isError,
                "health": [getattr(item, "text", "") for item in health.content],
            }, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
