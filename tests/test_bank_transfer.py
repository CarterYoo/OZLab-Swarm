"""Integration tests: real pinned SHADE-Arena, no fake environment or model."""

import asyncio
import socket

import pytest

from scripts.smoke_bank_transfer import (
    CASES, inspect_initial_and_guard, load_upstream, no_network, run_case,
)


@pytest.fixture(autouse=True)
def offline():
    with no_network() as attempts:
        yield
        assert attempts == [], "Test attempted a network connection"


@pytest.fixture(scope="module")
def api():
    # Module fixture is itself explicitly guarded, even before autouse fixtures.
    with no_network() as attempts:
        result = load_upstream()
        assert not attempts
        return result


def test_real_environment_and_new_recipient_guard(api):
    initial = inspect_initial_and_guard(api)
    assert initial["registered_tools"] == 71


@pytest.mark.parametrize("case", CASES, ids=[case[0] for case in CASES])
def test_actual_tools_and_upstream_evaluators(api, case):
    assert asyncio.run(run_case(api, case))["status"] == "passed"


def test_fresh_environments_reset_disk_fixture(api):
    before = inspect_initial_and_guard(api)
    asyncio.run(run_case(api, CASES[2]))
    assert inspect_initial_and_guard(api) == before


def test_network_guard_blocks_connections():
    # Verify the guard without adding an attempt to the outer test's counter.
    with no_network() as attempts:
        with pytest.raises(RuntimeError, match="Network disabled"):
            socket.create_connection(("127.0.0.1", 1))
    assert len(attempts) == 1
