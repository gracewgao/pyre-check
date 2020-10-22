# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import logging
from pathlib import Path

from ... import commands, configuration as configuration_module
from . import server_connection


LOG: logging.Logger = logging.getLogger(__name__)


def stop_server(socket_path: Path) -> None:
    with server_connection.connect_in_text_mode(socket_path) as (
        input_channel,
        output_channel,
    ):
        output_channel.write('["Stop"]\n')
        # Wait for the server to shutdown on its side
        input_channel.read()


def run(configuration: configuration_module.Configuration) -> commands.ExitCode:
    socket_path = server_connection.get_default_socket_path(
        log_directory=Path(configuration.log_directory)
    )
    try:
        stop_server(socket_path)

        local_root = configuration.local_root
        server_root = (
            local_root if local_root is not None else configuration.project_root
        )
        LOG.info(f"Stopped server at {server_root}\n")
        return commands.ExitCode.SUCCESS
    except Exception as error:
        LOG.error(f"Exception occured during server stop: {error}")
        return commands.ExitCode.FAILURE