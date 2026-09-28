import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import { Box, NoticeBox, Tabs } from 'tgui/components';
import { Window } from 'tgui/layouts';

interface CareerRow {
  ckey: string;
  name: string;
  kills: number;
  deaths: number;
  assists: number;
  captures: number;
  kd: number;
  accuracy: number;
  rounds: number;
  wins: number;
  win_rate: number;
  mvps: number;
  best_streak: number;
  best_round_kills: number;
  last_played?: string;
}

interface StatsData {
  viewer: string;
  own: CareerRow | null;
  board: CareerRow[];
  kd_floor: number;
  board_size: number;
}

type SortKey = 'kills' | 'kd' | 'wins' | 'mvps' | 'best_streak' | 'accuracy';

const SORTS: { key: SortKey; label: string }[] = [
  { key: 'kills', label: 'Kills' },
  { key: 'kd', label: 'K/D' },
  { key: 'wins', label: 'Wins' },
  { key: 'mvps', label: 'MVPs' },
  { key: 'best_streak', label: 'Best streak' },
  { key: 'accuracy', label: 'Accuracy' },
];

const Tile = (props: {
  readonly label: string;
  readonly value: string | number;
  readonly sub?: string;
  readonly big?: boolean;
}) => {
  const { label, value, sub, big } = props;
  return (
    <div
      className={
        big ? 'ClashStats__tile ClashStats__tile--big' : 'ClashStats__tile'
      }
    >
      <div className="ClashStats__tileValue">{value}</div>
      <div className="ClashStats__tileLabel">{label}</div>
      {sub && <div className="ClashStats__tileSub">{sub}</div>}
    </div>
  );
};

const rankOf = (
  board: CareerRow[],
  ckey: string,
  key: SortKey,
  floor: number,
) => {
  const pool =
    key === 'kd' || key === 'accuracy'
      ? board.filter((row) => row.kills >= floor)
      : board;
  const sorted = [...pool].sort((a, b) => b[key] - a[key] || b.kills - a.kills);
  const index = sorted.findIndex((row) => row.ckey === ckey);
  return index < 0 ? null : { rank: index + 1, of: sorted.length };
};

const Career = (props: {
  readonly own: CareerRow | null;
  readonly board: CareerRow[];
  readonly floor: number;
}) => {
  const { own, board, floor } = props;
  if (!own) {
    return (
      <NoticeBox info>
        No finished rounds on record yet. Stats are saved when a round ends.
      </NoticeBox>
    );
  }
  return (
    <>
      <div className="ClashStats__name">{own.name}</div>
      <div className="ClashStats__ranks">
        {SORTS.map((option) => {
          const place = rankOf(board, own.ckey, option.key, floor);
          return (
            <span
              key={option.key}
              className={
                place && place.rank <= 3
                  ? 'ClashStats__rankChip ClashStats__rankChip--top'
                  : 'ClashStats__rankChip'
              }
            >
              {option.label} <b>{place ? `#${place.rank}` : '-'}</b>
              {place && <span className="ClashStats__of"> of {place.of}</span>}
            </span>
          );
        })}
      </div>
      <div className="ClashStats__grid">
        <Tile big label="Kills" value={own.kills} />
        <Tile big label="K/D" value={own.kd.toFixed(2)} />
        <Tile
          big
          label="Wins"
          value={own.wins}
          sub={`${own.win_rate}% of ${own.rounds} rounds`}
        />
        <Tile big label="MVPs" value={own.mvps} />
        <Tile label="Deaths" value={own.deaths} />
        <Tile label="Assists" value={own.assists} />
        <Tile label="Accuracy" value={`${own.accuracy}%`} />
        <Tile label="Flag captures" value={own.captures} />
        <Tile label="Best streak" value={own.best_streak} />
        <Tile label="Best round" value={`${own.best_round_kills} kills`} />
      </div>
      {own.last_played && (
        <Box color="label" mt={1}>
          Last played {own.last_played}
        </Box>
      )}
    </>
  );
};

const Leaderboard = (props: {
  readonly board: CareerRow[];
  readonly viewer: string;
  readonly kdFloor: number;
  readonly size: number;
}) => {
  const { board, viewer, kdFloor, size } = props;
  const [sort, setSort] = useState<SortKey>('kills');
  const eligible =
    sort === 'kd' || sort === 'accuracy'
      ? board.filter((row) => row.kills >= kdFloor)
      : board;
  const rows = [...eligible]
    .sort((a, b) => b[sort] - a[sort] || b.kills - a.kills)
    .slice(0, size);
  const format = (row: CareerRow) => {
    switch (sort) {
      case 'kd':
        return row.kd.toFixed(2);
      case 'accuracy':
        return `${row.accuracy}%`;
      default:
        return row[sort];
    }
  };
  return (
    <>
      <div className="ClashStats__sorts">
        {SORTS.map((option) => (
          <span
            key={option.key}
            className={
              sort === option.key
                ? 'ClashStats__sort ClashStats__sort--active'
                : 'ClashStats__sort'
            }
            onClick={() => setSort(option.key)}
          >
            {option.label}
          </span>
        ))}
      </div>
      {(sort === 'kd' || sort === 'accuracy') && (
        <Box color="label" mb={1}>
          Players with at least {kdFloor} kills.
        </Box>
      )}
      <table className="ClashStats__table">
        <thead>
          <tr>
            <th>#</th>
            <th className="ClashStats__nameCol">Player</th>
            <th>{SORTS.find((option) => option.key === sort)?.label}</th>
            <th>K</th>
            <th>D</th>
            <th>K/D</th>
            <th>Wins</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={row.ckey}
              className={
                row.ckey === viewer ? 'ClashStats__row--viewer' : undefined
              }
            >
              <td
                className={
                  i < 3 ? `ClashStats__rank ClashStats__rank--${i + 1}` : ''
                }
              >
                {i + 1}
              </td>
              <td className="ClashStats__nameCol">{row.name}</td>
              <td className="ClashStats__main">{format(row)}</td>
              <td>{row.kills}</td>
              <td>{row.deaths}</td>
              <td>{row.kd.toFixed(2)}</td>
              <td>{row.wins}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {!rows.length && <NoticeBox>Nobody qualifies yet.</NoticeBox>}
    </>
  );
};

export const ClashStats = () => {
  const { data } = useBackend<StatsData>();
  const [tab, setTab] = useState<'career' | 'board'>('career');
  return (
    <Window width={560} height={520}>
      <Window.Content scrollable className="ClashStats">
        <Tabs>
          <Tabs.Tab
            icon="user"
            selected={tab === 'career'}
            onClick={() => setTab('career')}
          >
            Your career
          </Tabs.Tab>
          <Tabs.Tab
            icon="trophy"
            selected={tab === 'board'}
            onClick={() => setTab('board')}
          >
            Leaderboard
          </Tabs.Tab>
        </Tabs>
        {tab === 'career' ? (
          <Career own={data.own} board={data.board} floor={data.kd_floor} />
        ) : (
          <Leaderboard
            board={data.board}
            viewer={data.viewer}
            kdFloor={data.kd_floor}
            size={data.board_size}
          />
        )}
      </Window.Content>
    </Window>
  );
};
