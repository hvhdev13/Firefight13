import type { BooleanLike } from 'common/react';
import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

interface Side {
  faction: string;
  on: BooleanLike;
  bots: number;
  players: number;
  spawners: number;
  idle: number;
  fill_spawners: number;
  fill_target: number;
  cap: number;
}

interface Bot {
  ref: string;
  name: string;
  faction: string;
  health: number;
  state: string;
  area: string | null;
}

interface PanelData {
  enabled: BooleanLike;
  respawn_delay: number | null;
  hvh_round: BooleanLike;
  sides: Side[];
  bots: Bot[];
  max_team: number;
  max_spawn: number;
  max_respawn: number;
}

const SideSection = (props: { readonly side: Side }) => {
  const { act, data } = useBackend<PanelData>();
  const { side } = props;
  const [count, setCount] = useState(1);
  const faction = side.faction;
  return (
    <Section
      title={`${faction}: ${side.bots} bot${side.bots === 1 ? '' : 's'}, ${side.players} player${side.players === 1 ? '' : 's'}`}
      buttons={
        <>
          <Button
            icon={side.on ? 'toggle-on' : 'toggle-off'}
            color={side.on ? 'good' : 'bad'}
            tooltip="When off, this side's spawners send out no bots. Bots already out keep fighting."
            onClick={() => act('toggle_side', { faction })}
          >
            Spawning {side.on ? 'on' : 'off'}
          </Button>
          <Button.Confirm
            icon="trash"
            color="bad"
            disabled={!side.bots}
            onClick={() => act('clear', { faction })}
          >
            Clear side
          </Button.Confirm>
        </>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Spawners">
          {side.spawners
            ? `${side.spawners} on the map, ${side.idle} idle, ${side.fill_spawners} team fill`
            : 'None on this map'}
        </LabeledList.Item>
        <LabeledList.Item
          label="Team fill"
          tooltip="Team fill spawners top this side up to this many fighters, counting players."
        >
          <NumberInput
            width="4em"
            step={1}
            minValue={0}
            maxValue={data.max_team}
            value={side.fill_target}
            onChange={(value) => act('set_fill', { faction, value })}
          />
        </LabeledList.Item>
        <LabeledList.Item
          label="Bot cap"
          tooltip="Most bots this side may have alive at once."
        >
          <NumberInput
            width="4em"
            step={1}
            minValue={0}
            maxValue={data.max_team}
            value={side.cap}
            onChange={(value) => act('set_cap', { faction, value })}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Spawn">
          <NumberInput
            width="3em"
            step={1}
            minValue={1}
            maxValue={data.max_spawn}
            value={count}
            onChange={(value) => setCount(value)}
          />
          <Button
            ml={1}
            icon="users"
            disabled={!side.idle}
            tooltip="Sends bots out from idle spawners. They respawn like any other."
            onClick={() => act('spawn', { faction, count })}
          >
            At spawners
          </Button>
          <Button
            icon="location-dot"
            tooltip="Spawns bots where you stand. They do not respawn and are removed at the next match."
            onClick={() => act('spawn_here', { faction, count })}
          >
            Here
          </Button>
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

export const ClashBotPanel = () => {
  const { act, data } = useBackend<PanelData>();
  const { enabled, respawn_delay, hvh_round, sides, bots } = data;
  return (
    <Window width={620} height={720} theme="crtblue">
      <Window.Content scrollable>
        {!hvh_round && (
          <NoticeBox>
            This is not an HvH round. Bots only exist where a map places
            spawners.
          </NoticeBox>
        )}
        <Section
          title="All bots"
          buttons={
            <>
              <Button
                icon={enabled ? 'pause' : 'play'}
                color={enabled ? 'default' : 'average'}
                tooltip="Paused bots stand still, hold fire and do not spawn."
                onClick={() => act('toggle_all')}
              >
                {enabled ? 'Pause all' : 'Resume all'}
              </Button>
              <Button.Confirm
                icon="trash"
                color="bad"
                disabled={!bots.length}
                onClick={() => act('clear')}
              >
                Clear all
              </Button.Confirm>
            </>
          }
        >
          <LabeledList>
            <LabeledList.Item
              label="Respawn delay"
              tooltip="Seconds before a dead bot is replaced. 0 means never."
            >
              <NumberInput
                width="4em"
                step={5}
                minValue={0}
                maxValue={data.max_respawn}
                value={respawn_delay ?? 30}
                unit="s"
                onChange={(value) => act('set_respawn', { value })}
              />
              <Button
                ml={1}
                selected={respawn_delay === null}
                onClick={() => act('set_respawn')}
              >
                Spawner default
              </Button>
            </LabeledList.Item>
          </LabeledList>
          <Box mt={1} color="label">
            Cleared or removed bots come back at the next match, or when their
            spawner is sent out again.
          </Box>
        </Section>
        <Stack vertical>
          {sides.map((side) => (
            <Stack.Item key={side.faction}>
              <SideSection side={side} />
            </Stack.Item>
          ))}
        </Stack>
        <Section title={`Bots alive (${bots.length})`}>
          {bots.length ? (
            <Table>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Side</Table.Cell>
                <Table.Cell>Health</Table.Cell>
                <Table.Cell>State</Table.Cell>
                <Table.Cell>Area</Table.Cell>
                <Table.Cell />
              </Table.Row>
              {bots.map((bot) => (
                <Table.Row key={bot.ref}>
                  <Table.Cell>{bot.name}</Table.Cell>
                  <Table.Cell>{bot.faction}</Table.Cell>
                  <Table.Cell width="80px">
                    <ProgressBar
                      value={bot.health / 100}
                      ranges={{
                        good: [0.6, Infinity],
                        average: [0.3, 0.6],
                        bad: [-Infinity, 0.3],
                      }}
                    >
                      {bot.health}%
                    </ProgressBar>
                  </Table.Cell>
                  <Table.Cell>{bot.state}</Table.Cell>
                  <Table.Cell>{bot.area}</Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      icon="eye"
                      tooltip="Jump to"
                      onClick={() => act('jump', { ref: bot.ref })}
                    />
                    <Button
                      icon="xmark"
                      color="bad"
                      tooltip="Remove"
                      onClick={() => act('remove', { ref: bot.ref })}
                    />
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          ) : (
            <Box color="label">No bots alive.</Box>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
