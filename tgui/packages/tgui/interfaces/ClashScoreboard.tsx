import { KEY_TAB } from 'common/keycodes';
import { type BooleanLike, classes } from 'common/react';
import { useBackend } from 'tgui/backend';
import { Box, Button, Icon, KeyListener, NoticeBox } from 'tgui/components';
import { Window } from 'tgui/layouts';

interface Row {
  name: string;
  role?: string;
  alive: BooleanLike;
  kills: number;
  assists: number;
  deaths: number;
  captures: number;
  best_streak: number;
  streak: number;
  is_viewer: BooleanLike;
  mvp: BooleanLike;
}

interface Team {
  id: 'uscm' | 'upp';
  name: string;
  color: string;
  kills: number;
  deaths: number;
  score: number;
  wins: number;
  alive: number;
  own: BooleanLike;
  players: Row[];
}

interface Objective {
  label: string;
  state: string;
  color: string;
}

interface MatchResult {
  winner: 'uscm' | 'upp' | null;
  uscm: number;
  upp: number;
  mvp?: string;
}

interface ScoreboardData {
  active: BooleanLike;
  mode?: string;
  teams?: Team[];
  score_limit?: number;
  score_label?: string;
  limit_text?: string;
  objectives?: Objective[];
  seconds_left?: number;
  countdown?: number;
  intermission?: number;
  finished?: BooleanLike;
  match?: number;
  matches?: number;
  wins_needed?: number;
  results?: MatchResult[];
  awards?: string[];
  kits?: BooleanLike;
}

const byScore = (a: Row, b: Row) =>
  b.kills - a.kills ||
  b.captures - a.captures ||
  b.assists - a.assists ||
  a.deaths - b.deaths ||
  a.name.localeCompare(b.name);

const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

const ratio = (row: Row) =>
  row.deaths ? (row.kills / row.deaths).toFixed(2) : row.kills.toFixed(2);

const getStatus = (data: ScoreboardData) => {
  const { seconds_left = 0, countdown = 0, intermission = 0 } = data;
  if (data.finished) {
    return { big: 'FINAL', small: 'Round over' };
  }
  if (intermission) {
    return {
      big: `0:${String(intermission).padStart(2, '0')}`,
      small: 'Next match',
    };
  }
  if (countdown) {
    return { big: clock(countdown), small: 'Match starts' };
  }
  if (seconds_left) {
    return {
      big: clock(seconds_left),
      small: seconds_left <= 60 ? 'Final minute' : 'Time left',
      urgent: seconds_left <= 60,
    };
  }
  return { big: '--:--', small: 'Waiting' };
};

const SeriesPips = (props: {
  readonly team: Team;
  readonly needed: number;
  readonly flip?: boolean;
}) => {
  const { team, needed, flip } = props;
  const pips = Array.from({ length: needed }, (_, i) => i < team.wins);
  if (flip) {
    pips.reverse();
  }
  return (
    <div className="ClashScoreboard__pips">
      {pips.map((won, i) => (
        <span
          key={i}
          className={classes([
            'ClashScoreboard__pip',
            won && 'ClashScoreboard__pip--won',
          ])}
        />
      ))}
    </div>
  );
};

const TeamScore = (props: {
  readonly team: Team;
  readonly limit: number;
  readonly needed: number;
  readonly leading: boolean;
  readonly flip?: boolean;
  readonly label?: string;
}) => {
  const { team, limit, needed, leading, flip, label } = props;
  const fill = limit ? Math.min(100, (team.score / limit) * 100) : 0;
  return (
    <div
      className={classes([
        'ClashScoreboard__teamScore',
        flip && 'ClashScoreboard__teamScore--flip',
        leading && 'ClashScoreboard__teamScore--leading',
      ])}
      style={{ '--team-color': team.color } as React.CSSProperties}
    >
      <div className="ClashScoreboard__teamLine">
        <span className="ClashScoreboard__teamName">
          {team.name}
          {!!team.own && <span className="ClashScoreboard__you">YOU</span>}
        </span>
        <span className="ClashScoreboard__score">
          {team.score}
          {label && <span className="ClashScoreboard__unit">{label}</span>}
        </span>
      </div>
      {limit > 0 && (
        <div className="ClashScoreboard__bar">
          <div
            className="ClashScoreboard__barFill"
            style={{ width: `${fill}%` }}
          />
        </div>
      )}
      <div className="ClashScoreboard__teamMeta">
        <span>
          {team.alive}/{team.players.length} alive
        </span>
        {needed > 1 && <SeriesPips team={team} needed={needed} flip={flip} />}
      </div>
    </div>
  );
};

const TeamTable = (props: {
  readonly team: Team;
  readonly showCaptures: boolean;
}) => {
  const { team, showCaptures } = props;
  const rows = [...team.players].sort(byScore);
  return (
    <div
      className={classes([
        'ClashScoreboard__team',
        team.own && 'ClashScoreboard__team--own',
      ])}
      style={{ '--team-color': team.color } as React.CSSProperties}
    >
      <table className="ClashScoreboard__table">
        <thead>
          <tr>
            <th className="ClashScoreboard__rank">#</th>
            <th className="ClashScoreboard__nameCol">{team.name}</th>
            <th title="Kills">K</th>
            <th title="Assists">A</th>
            <th title="Deaths">D</th>
            {showCaptures && <th title="Flag captures">CAP</th>}
            <th title="Kills per death">K/D</th>
            <th title="Current streak (best)">STK</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={row.name}
              className={classes([
                row.is_viewer && 'ClashScoreboard__row--viewer',
                !row.alive && 'ClashScoreboard__row--dead',
              ])}
            >
              <td className="ClashScoreboard__rank">{i + 1}</td>
              <td className="ClashScoreboard__nameCol">
                <div className="ClashScoreboard__player">
                  <Icon
                    name={row.alive ? 'circle' : 'skull'}
                    className="ClashScoreboard__life"
                  />
                  <span className="ClashScoreboard__playerName">
                    {row.name}
                  </span>
                  {!!row.mvp && (
                    <span className="ClashScoreboard__mvp" title="Top player">
                      <Icon name="star" />
                    </span>
                  )}
                </div>
                {row.role && (
                  <div className="ClashScoreboard__role">{row.role}</div>
                )}
              </td>
              <td className="ClashScoreboard__kills">{row.kills}</td>
              <td>{row.assists}</td>
              <td>{row.deaths}</td>
              {showCaptures && <td>{row.captures}</td>}
              <td className="ClashScoreboard__dim">{ratio(row)}</td>
              <td>
                {row.streak >= 3 ? (
                  <span className="ClashScoreboard__hot">{row.streak}</span>
                ) : (
                  row.streak
                )}
                <span className="ClashScoreboard__dim">
                  {' '}
                  ({row.best_streak})
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {!rows.length && (
        <div className="ClashScoreboard__empty">No players yet</div>
      )}
      <div className="ClashScoreboard__teamFoot">
        <span>
          Team {team.kills} K / {team.deaths} D
        </span>
      </div>
    </div>
  );
};

const MatchStrip = (props: {
  readonly results: MatchResult[];
  readonly teams: Team[];
}) => {
  const { results, teams } = props;
  if (!results.length) {
    return null;
  }
  const color = (id: string | null) =>
    teams.find((team) => team.id === id)?.color ?? '#999';
  return (
    <div className="ClashScoreboard__strip">
      {results.map((result, i) => (
        <span
          key={i}
          className="ClashScoreboard__chip"
          style={{ borderColor: color(result.winner) }}
          title={result.mvp ? `MVP: ${result.mvp}` : undefined}
        >
          M{i + 1} <b style={{ color: color('uscm') }}>{result.uscm}</b>
          {' - '}
          <b style={{ color: color('upp') }}>{result.upp}</b>
          {result.mvp && (
            <span className="ClashScoreboard__dim"> · {result.mvp}</span>
          )}
        </span>
      ))}
    </div>
  );
};

export const ClashScoreboard = () => {
  const { act, data } = useBackend<ScoreboardData>();
  const {
    teams = [],
    limit_text,
    objectives = [],
    score_limit = 0,
    match = 1,
    matches = 1,
    wins_needed = 1,
    results = [],
    awards = [],
  } = data;
  const status = getStatus(data);
  const [left, right] = teams;
  const showCaptures = teams.some((team) =>
    team.players.some((row) => row.captures > 0),
  );

  return (
    <Window width={760} height={560}>
      <KeyListener
        onKeyDown={(key) => {
          if (key.code === KEY_TAB) {
            key.event.preventDefault();
            act('close');
          }
        }}
      />
      <Window.Content scrollable className="ClashScoreboard">
        {!data.active || !left || !right ? (
          <NoticeBox>There is no scoreboard this round.</NoticeBox>
        ) : (
          <>
            <div className="ClashScoreboard__header">
              <TeamScore
                label={data.score_label}
                team={left}
                limit={score_limit}
                needed={matches > 1 ? wins_needed : 0}
                leading={left.score > right.score}
              />
              <div className="ClashScoreboard__center">
                <div className="ClashScoreboard__mode">{data.mode}</div>
                <div
                  className={classes([
                    'ClashScoreboard__clock',
                    status.urgent && 'ClashScoreboard__clock--urgent',
                  ])}
                >
                  {status.big}
                </div>
                <div className="ClashScoreboard__status">{status.small}</div>
                {matches > 1 && (
                  <div className="ClashScoreboard__match">
                    Match {match} of {matches}
                  </div>
                )}
              </div>
              <TeamScore
                label={data.score_label}
                team={right}
                limit={score_limit}
                needed={matches > 1 ? wins_needed : 0}
                leading={right.score > left.score}
                flip
              />
            </div>
            <div className="ClashScoreboard__sub">
              {limit_text && <span>{limit_text}</span>}
              {objectives.map((objective) => (
                <span
                  key={objective.label}
                  className="ClashScoreboard__chip"
                  style={{ borderColor: objective.color }}
                >
                  <b style={{ color: objective.color }}>{objective.label}</b>{' '}
                  {objective.state}
                </span>
              ))}
              <MatchStrip results={results} teams={teams} />
            </div>
            {awards.length > 0 && (
              <div className="ClashScoreboard__awards">
                <Icon name="medal" mr={1} />
                {awards.map((award) => (
                  <span key={award} className="ClashScoreboard__award">
                    {award}
                  </span>
                ))}
              </div>
            )}
            <div className="ClashScoreboard__teams">
              <TeamTable team={left} showCaptures={showCaptures} />
              <TeamTable team={right} showCaptures={showCaptures} />
            </div>
            <div className="ClashScoreboard__footer">
              <Box color="label">
                <span className="ClashScoreboard__key">Tab</span> close
              </Box>
              {!!data.kits && (
                <Button icon="person-rifle" onClick={() => act('loadout')}>
                  Loadout
                </Button>
              )}
            </div>
          </>
        )}
      </Window.Content>
    </Window>
  );
};
