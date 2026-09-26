import { type BooleanLike } from 'common/react';
import { useBackend } from 'tgui/backend';
import { Box, NoticeBox, Section, Stack, Table } from 'tgui/components';
import { Window } from 'tgui/layouts';

interface Row {
  name: string;
  kills: number;
  assists: number;
  deaths: number;
  best_streak: number;
  streak: number;
  is_viewer: BooleanLike;
}

interface Team {
  name: string;
  color: string;
  kills: number;
  score?: number;
  players: Row[];
}

interface Objective {
  label: string;
  state: string;
  color: string;
}

interface ScoreboardData {
  active: BooleanLike;
  mode?: string;
  teams?: Team[];
  kill_limit?: number;
  score_label?: string;
  limit_text?: string;
  objectives?: Objective[];
  seconds_left?: number;
  countdown?: number;
  intermission?: number;
  finished?: BooleanLike;
  match?: number;
  matches?: number;
  series?: [number, number];
}

const byScore = (a: Row, b: Row) =>
  b.kills - a.kills || b.assists - a.assists || a.deaths - b.deaths;

const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

const TeamTable = (props: { readonly team: Team }) => {
  const { team } = props;
  const rows = [...team.players].sort(byScore);
  return (
    <Section
      title={
        <Box as="span" color={team.color}>
          {team.name} &middot; {team.score ?? team.kills}
        </Box>
      }
    >
      <Table>
        <Table.Row header>
          <Table.Cell>Player</Table.Cell>
          <Table.Cell collapsing textAlign="right">
            K
          </Table.Cell>
          <Table.Cell collapsing textAlign="right">
            A
          </Table.Cell>
          <Table.Cell collapsing textAlign="right">
            D
          </Table.Cell>
          <Table.Cell collapsing textAlign="right">
            Streak
          </Table.Cell>
        </Table.Row>
        {rows.map((row) => (
          <Table.Row key={row.name} bold={!!row.is_viewer}>
            <Table.Cell>{row.name}</Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {row.kills}
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {row.assists}
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {row.deaths}
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {row.streak} ({row.best_streak})
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
      {!rows.length && <Box color="label">No players</Box>}
    </Section>
  );
};

export const ClashScoreboard = () => {
  const { data } = useBackend<ScoreboardData>();
  const {
    teams = [],
    limit_text,
    objectives = [],
    seconds_left = 0,
    countdown = 0,
    intermission = 0,
    match = 1,
    matches = 1,
    series = [0, 0],
  } = data;

  let status = '';
  if (data.finished) {
    status = 'Round over';
  } else if (intermission) {
    status = `Next match in ${intermission}`;
  } else if (countdown) {
    status = `Match starts in ${countdown}`;
  } else if (seconds_left) {
    status = `${clock(seconds_left)} left`;
  }

  return (
    <Window width={640} height={520}>
      <Window.Content scrollable>
        {!data.active ? (
          <NoticeBox>There is no scoreboard this round.</NoticeBox>
        ) : (
          <>
            <Box mb={1} color="label">
              {data.mode}
              {matches > 1
                ? ` · Match ${match} of ${matches} · Series ${series[0]}-${series[1]}`
                : ''}
              {limit_text ? ` · ${limit_text}` : ''}
              {status ? ` · ${status}` : ''}
            </Box>
            {objectives.length > 0 && (
              <Box mb={1}>
                {objectives.map((objective) => (
                  <Box
                    as="span"
                    key={objective.label}
                    mr={2}
                    color={objective.color}
                  >
                    {objective.label}: {objective.state}
                  </Box>
                ))}
              </Box>
            )}
            <Stack>
              {teams.map((team) => (
                <Stack.Item grow basis={0} key={team.name}>
                  <TeamTable team={team} />
                </Stack.Item>
              ))}
            </Stack>
          </>
        )}
      </Window.Content>
    </Window>
  );
};
