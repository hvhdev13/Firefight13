import type { BooleanLike } from 'common/react';
import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Table,
  Tabs,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import type { CareerProgress, CareerRow } from './ClashStats';

interface BoostData {
  active: BooleanLike;
  multiplier: number;
  left: string | null;
  started_by: string | null;
  max: number;
  max_hours: number;
  max_rounds: number;
}

interface OnlinePlayer {
  ckey: string;
  name: string | null;
  job: string | null;
  side: string | null;
}

interface PerkEntry {
  type: string;
  name: string;
  class?: string;
}

interface RoleEntry {
  title: string;
  side: string;
  class: string;
  level: number;
}

interface LiveData {
  name: string;
  state: string;
  job: string | null;
  side: string | null;
  class: string | null;
  perks: PerkEntry[];
  can_edit: BooleanLike;
  can_regear: BooleanLike;
}

interface RoundData {
  ledger: { source: string; xp: number }[];
  medical: number;
  engineering: number;
  unlocks: { header: string; name: string; color: string }[];
  start_levels: { name: string; level: number }[];
  short_side: string | null;
}

interface LoadoutKit {
  name: string;
  active: BooleanLike;
  extras: number;
  picks: { slot: string; name: string; lock: string | null }[];
}

interface PlayerData {
  live: LiveData | null;
  toasts: BooleanLike;
  radar: BooleanLike;
  round: RoundData;
  career: CareerRow | null;
  loadout: { job: string; kits: LoadoutKit[] };
}

interface PanelData {
  enabled: BooleanLike;
  multiplier: number;
  bot_xp: BooleanLike;
  boost: BoostData;
  gating: BooleanLike;
  online: OnlinePlayer[];
  ckey: string | null;
  saved: BooleanLike;
  progress: CareerProgress | null;
  player: PlayerData | null;
  max_multiplier: number;
  level_cap: number;
  perks: PerkEntry[];
  roles: RoleEntry[];
  medical_cap: number;
  engineering_cap: number;
}

const LevelInput = (props: {
  readonly track: string;
  readonly id: string;
  readonly value: number;
  readonly min: number;
  readonly max: number;
}) => {
  const { act } = useBackend<PanelData>();
  const { track, id, value, min, max } = props;
  return (
    <NumberInput
      width="4em"
      step={1}
      minValue={min}
      maxValue={max}
      value={value}
      onChange={(level) => act('set_level', { track, key: id, level })}
    />
  );
};

const XpInput = (props: {
  readonly track: string;
  readonly id: string;
  readonly value: number;
}) => {
  const { act } = useBackend<PanelData>();
  const { track, id, value } = props;
  return (
    <NumberInput
      width="6em"
      step={100}
      minValue={0}
      maxValue={9999999}
      value={value}
      onChange={(xp) => act('set_xp', { track, key: id, xp })}
    />
  );
};

const RoleList = (props: {
  readonly roles: RoleEntry[];
  readonly reached: number | null;
  readonly current: string | null;
}) => {
  const { roles, reached, current } = props;
  return (
    <Box color="label" mt={0.5}>
      {roles.map((role, index) => (
        <Box
          as="span"
          key={role.title}
          bold={role.title === current}
          color={reached === null || role.level <= reached ? 'good' : 'average'}
        >
          {index > 0 && ', '}
          {role.title}
          {reached !== null && ` (${role.level})`}
        </Box>
      ))}
    </Box>
  );
};

const Overview = (props: { readonly player: PlayerData }) => {
  const { act, data } = useBackend<PanelData>();
  const { live } = props.player;
  const [perk, setPerk] = useState<string | null>(null);
  return (
    <>
      <Section
        title="Right now"
        buttons={
          <>
            <Button
              icon="shirt"
              disabled={!live?.can_regear}
              tooltip="Re-issue their active loadout to their body now"
              onClick={() => act('regear')}
            >
              Re-gear now
            </Button>
            <Button icon="pen" onClick={() => act('open_loadout')}>
              Open loadout editor
            </Button>
          </>
        }
      >
        {live ? (
          <LabeledList>
            <LabeledList.Item label="Character">{live.name}</LabeledList.Item>
            <LabeledList.Item label="State">{live.state}</LabeledList.Item>
            <LabeledList.Item label="Side">
              {live.side ?? 'None'}
            </LabeledList.Item>
            <LabeledList.Item label="Role">
              {live.job ?? 'None'}
            </LabeledList.Item>
            <LabeledList.Item label="Class">
              {live.class ?? 'None'}
            </LabeledList.Item>
            <LabeledList.Item label="Live perks">
              {live.perks.length
                ? live.perks.map((owned) => (
                    <Button
                      key={owned.type}
                      icon="times"
                      color="transparent"
                      disabled={!live.can_edit}
                      tooltip="Remove until their next spawn"
                      onClick={() => act('perk_remove', { type: owned.type })}
                    >
                      {owned.name}
                    </Button>
                  ))
                : 'None'}
            </LabeledList.Item>
            <LabeledList.Item label="Add perk">
              <Dropdown
                width="16em"
                disabled={!live.can_edit}
                options={data.perks.map((entry) => ({
                  displayText: `${entry.name} (${entry.class})`,
                  value: entry.type,
                }))}
                selected={perk}
                placeholder="Pick a perk"
                onSelected={setPerk}
              />{' '}
              <Button
                icon="plus"
                disabled={!live.can_edit || !perk}
                onClick={() => act('perk_add', { type: perk })}
              >
                Add
              </Button>
            </LabeledList.Item>
          </LabeledList>
        ) : (
          <NoticeBox>
            Offline. Levels, XP and loadouts can still be edited.
          </NoticeBox>
        )}
        <NoticeBox info mt={1}>
          Live perks only change the body they are playing now. They are
          replaced by the loadout&apos;s perks when the player respawns or is
          re-geared. Perks that hand out gear at spawn need a re-gear.
        </NoticeBox>
      </Section>
      <Section title="Their settings">
        <LabeledList>
          <LabeledList.Item label="Unlock popups">
            {props.player.toasts ? 'On' : 'Off'}
          </LabeledList.Item>
          <LabeledList.Item label="Radar">
            {props.player.radar ? 'On' : 'Off'}
          </LabeledList.Item>
        </LabeledList>
      </Section>
    </>
  );
};

const Levels = (props: {
  readonly progress: CareerProgress;
  readonly player: PlayerData;
}) => {
  const { act, data } = useBackend<PanelData>();
  const { progress, player } = props;
  const current = player.live?.job ?? null;
  return (
    <>
      <Section
        title="Faction levels"
        buttons={
          <>
            <Button icon="angles-up" onClick={() => act('fill_all')}>
              Max everything
            </Button>
            <Button
              icon="rotate-left"
              color="bad"
              onClick={() => act('reset_all')}
            >
              Reset everything
            </Button>
          </>
        }
      >
        <LabeledList>
          {progress.factions.map((faction) => (
            <LabeledList.Item key={faction.id} label={faction.side}>
              <LevelInput
                track="faction"
                id={faction.id}
                value={faction.level}
                min={1}
                max={data.level_cap}
              />{' '}
              {faction.insignia},{' '}
              <XpInput track="faction" id={faction.id} value={faction.xp} /> XP
              <RoleList
                roles={data.roles.filter((role) => role.side === faction.side)}
                reached={faction.level}
                current={current}
              />
            </LabeledList.Item>
          ))}
        </LabeledList>
        <Box color="label" mt={1}>
          Roles unlock at the faction level in brackets. Green roles are open to
          this player.
        </Box>
      </Section>
      <Section title="Class levels">
        <LabeledList>
          {progress.classes.map((entry) => (
            <LabeledList.Item key={entry.id} label={entry.name}>
              <LevelInput
                track="class"
                id={entry.id}
                value={entry.level}
                min={1}
                max={data.level_cap}
              />{' '}
              <XpInput track="class" id={entry.id} value={entry.xp} /> XP
              <RoleList
                roles={data.roles.filter((role) => role.class === entry.id)}
                reached={null}
                current={current}
              />
            </LabeledList.Item>
          ))}
        </LabeledList>
        <Box color="label" mt={1}>
          Every role listed under a class earns and uses that class level.
        </Box>
      </Section>
    </>
  );
};

const Weapons = (props: { readonly progress: CareerProgress }) => {
  const { progress } = props;
  return (
    <>
      <Section title="Ammo carriers">
        <LabeledList>
          {progress.carriers.map((carrier) => (
            <LabeledList.Item key={carrier.id} label={`${carrier.family} ammo`}>
              <LevelInput
                track="carrier"
                id={carrier.id}
                value={carrier.step}
                min={0}
                max={carrier.steps}
              />{' '}
              of {carrier.steps} carriers, {carrier.xp.toLocaleString('en-US')}{' '}
              XP
            </LabeledList.Item>
          ))}
        </LabeledList>
      </Section>
      <Section title="Weapons">
        <Table>
          {progress.weapons.map((weapon) => (
            <Table.Row key={weapon.type}>
              <Table.Cell>{weapon.name}</Table.Cell>
              <Table.Cell collapsing>
                <LevelInput
                  track="weapon"
                  id={weapon.type}
                  value={weapon.level}
                  min={1}
                  max={weapon.max}
                />
              </Table.Cell>
              <Table.Cell collapsing>of {weapon.max}</Table.Cell>
              <Table.Cell collapsing>
                <XpInput track="weapon" id={weapon.type} value={weapon.xp} /> XP
              </Table.Cell>
              <Table.Cell collapsing>
                {!!weapon.mastered && 'Mastered'}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      </Section>
    </>
  );
};

const Loadouts = (props: { readonly player: PlayerData }) => {
  const { act, data } = useBackend<PanelData>();
  const { loadout } = props.player;
  return (
    <Section
      title="Loadouts"
      buttons={
        <Button icon="pen" onClick={() => act('open_loadout')}>
          Open loadout editor
        </Button>
      }
    >
      <Dropdown
        width="22em"
        options={data.roles.map((role) => ({
          displayText: `${role.side}: ${role.title}`,
          value: role.title,
        }))}
        selected={loadout.job}
        onSelected={(job) => act('loadout_job', { job })}
      />
      {!data.gating && (
        <NoticeBox mt={1}>
          Locks are off right now, so nothing in these loadouts is swapped out.
        </NoticeBox>
      )}
      {loadout.kits.map((kit) => (
        <Section
          key={kit.name}
          mt={1}
          title={kit.active ? `${kit.name} (active)` : kit.name}
        >
          {kit.picks.length ? (
            <Table>
              {kit.picks.map((pick) => (
                <Table.Row key={pick.slot}>
                  <Table.Cell collapsing color="label">
                    {pick.slot}
                  </Table.Cell>
                  <Table.Cell>{pick.name}</Table.Cell>
                  <Table.Cell color="bad">
                    {pick.lock && `Swapped at spawn: ${pick.lock}`}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          ) : (
            <Box color="label">
              Nothing picked, the role&apos;s default gear.
            </Box>
          )}
          {kit.extras > 0 && (
            <Box color="label" mt={0.5}>
              {kit.extras} shop item{kit.extras === 1 ? '' : 's'} bought.
            </Box>
          )}
        </Section>
      ))}
    </Section>
  );
};

const ThisRound = (props: { readonly player: PlayerData }) => {
  const { data } = useBackend<PanelData>();
  const { round } = props.player;
  const total = round.ledger.reduce((sum, entry) => sum + entry.xp, 0);
  return (
    <>
      <Section title="XP this round">
        {round.ledger.length ? (
          <Table>
            {round.ledger.map((entry) => (
              <Table.Row key={entry.source}>
                <Table.Cell>{entry.source}</Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  {entry.xp.toLocaleString('en-US')}
                </Table.Cell>
              </Table.Row>
            ))}
            <Table.Row bold>
              <Table.Cell>Total</Table.Cell>
              <Table.Cell collapsing textAlign="right">
                {total.toLocaleString('en-US')}
              </Table.Cell>
            </Table.Row>
          </Table>
        ) : (
          <Box color="label">No XP earned this round.</Box>
        )}
      </Section>
      <Section title="Caps and bonuses">
        <LabeledList>
          <LabeledList.Item label="Medical XP">
            {round.medical} of {data.medical_cap}
          </LabeledList.Item>
          <LabeledList.Item label="Engineering XP">
            {round.engineering} of {data.engineering_cap}
          </LabeledList.Item>
          <LabeledList.Item label="Short side bonus">
            {round.short_side ? `Yes, on ${round.short_side}` : 'No'}
          </LabeledList.Item>
          <LabeledList.Item label="Levels at round start">
            {round.start_levels.length
              ? round.start_levels
                  .map((entry) => `${entry.name} ${entry.level}`)
                  .join(', ')
              : 'Not spawned yet'}
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section title="Unlocks this round">
        {round.unlocks.length ? (
          round.unlocks.map((unlock, index) => (
            <Box key={index}>
              <Box as="span" color={unlock.color} bold>
                {unlock.header}
              </Box>{' '}
              {unlock.name}
            </Box>
          ))
        ) : (
          <Box color="label">None yet.</Box>
        )}
      </Section>
    </>
  );
};

const Career = (props: { readonly career: CareerRow | null }) => {
  const { career } = props;
  if (!career) {
    return (
      <Section title="Career">
        <Box color="label">No finished rounds recorded yet.</Box>
      </Section>
    );
  }
  return (
    <Section title="Career">
      <LabeledList>
        <LabeledList.Item label="Name">{career.name}</LabeledList.Item>
        <LabeledList.Item label="Rounds">
          {career.rounds}, {career.wins} won ({career.win_rate}%)
        </LabeledList.Item>
        <LabeledList.Item label="Kills">
          {career.kills}, {career.deaths} deaths, K/D {career.kd}
        </LabeledList.Item>
        <LabeledList.Item label="Assists">{career.assists}</LabeledList.Item>
        <LabeledList.Item label="Captures">{career.captures}</LabeledList.Item>
        <LabeledList.Item label="Accuracy">{career.accuracy}%</LabeledList.Item>
        <LabeledList.Item label="MVPs">{career.mvps}</LabeledList.Item>
        <LabeledList.Item label="Best streak">
          {career.best_streak}
        </LabeledList.Item>
        <LabeledList.Item label="Best round">
          {career.best_round_kills} kills
        </LabeledList.Item>
        <LabeledList.Item label="Last played">
          {career.last_played ?? 'Unknown'}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const PLAYER_TABS = [
  'Overview',
  'Levels',
  'Weapons',
  'Loadouts',
  'This round',
  'Career',
];

const PlayerTab = () => {
  const { act, data } = useBackend<PanelData>();
  const [tab, setTab] = useState('Overview');
  const online = [...data.online].sort((a, b) => a.ckey.localeCompare(b.ckey));
  return (
    <>
      <Section title="Player">
        <Dropdown
          width="100%"
          options={online.map((player) => ({
            displayText: `${player.ckey}${player.name ? `, ${player.name}` : ''}${player.side ? ` (${player.side} ${player.job})` : ''}`,
            value: player.ckey,
          }))}
          selected={data.ckey}
          placeholder="Pick an online player"
          onSelected={(ckey) => act('lookup', { ckey })}
        />
        <Input
          fluid
          mt={1}
          placeholder="Or type any ckey, then Enter"
          onEnter={(_, value) => act('lookup', { ckey: value })}
        />
        {!!data.ckey && !data.saved && (
          <NoticeBox warning mt={1}>
            No save for {data.ckey}. Editing creates one.
          </NoticeBox>
        )}
      </Section>
      {data.progress && data.player ? (
        <>
          <Tabs>
            {PLAYER_TABS.map((name) => (
              <Tabs.Tab
                key={name}
                selected={tab === name}
                onClick={() => setTab(name)}
              >
                {name}
              </Tabs.Tab>
            ))}
          </Tabs>
          {tab === 'Overview' && <Overview player={data.player} />}
          {tab === 'Levels' && (
            <Levels progress={data.progress} player={data.player} />
          )}
          {tab === 'Weapons' && <Weapons progress={data.progress} />}
          {tab === 'Loadouts' && <Loadouts player={data.player} />}
          {tab === 'This round' && <ThisRound player={data.player} />}
          {tab === 'Career' && <Career career={data.player.career} />}
        </>
      ) : (
        data.ckey && <NoticeBox>No progression for {data.ckey}.</NoticeBox>
      )}
    </>
  );
};

const XpBoost = () => {
  const { act, data } = useBackend<PanelData>();
  const { boost } = data;
  const [multiplier, setMultiplier] = useState(2);
  const [amount, setAmount] = useState(48);
  const [unit, setUnit] = useState('hours');
  return (
    <Section
      title="XP boost"
      buttons={
        !!boost.active && (
          <Button color="bad" onClick={() => act('boost_end')}>
            End boost
          </Button>
        )
      }
    >
      {boost.active ? (
        <NoticeBox success>
          {boost.multiplier}x XP {boost.left}, started by {boost.started_by}.
          Starting a new boost replaces it.
        </NoticeBox>
      ) : (
        <NoticeBox>No boost is running.</NoticeBox>
      )}
      <LabeledList>
        <LabeledList.Item label="Multiplier">
          <NumberInput
            width="4em"
            step={0.25}
            minValue={1.25}
            maxValue={boost.max}
            value={multiplier}
            onChange={setMultiplier}
          />
          x
        </LabeledList.Item>
        <LabeledList.Item label="Runs for">
          <NumberInput
            width="4em"
            step={1}
            minValue={1}
            maxValue={unit === 'rounds' ? boost.max_rounds : boost.max_hours}
            value={amount}
            onChange={setAmount}
          />{' '}
          <Dropdown
            width="7em"
            options={['hours', 'rounds']}
            selected={unit}
            onSelected={setUnit}
          />
        </LabeledList.Item>
      </LabeledList>
      <Button
        mt={1}
        icon="bolt"
        onClick={() => act('boost_start', { multiplier, amount, unit })}
      >
        Start boost
      </Button>
      <NoticeBox mt={1} info>
        Hours count real time, server restarts included. Rounds count arena
        rounds that reach the end screen. The boost stacks with the XP
        multiplier above and survives restarts.
      </NoticeBox>
    </Section>
  );
};

const ServerTab = () => {
  const { act, data } = useBackend<PanelData>();
  return (
    <>
      <Section title="Settings">
        <LabeledList>
          <LabeledList.Item label="Locks">
            <Button.Checkbox
              checked={!!data.enabled}
              onClick={() => act('enabled')}
            >
              {data.enabled
                ? 'On'
                : 'Off: everything is unlocked, XP is still earned'}
            </Button.Checkbox>
          </LabeledList.Item>
          <LabeledList.Item label="XP multiplier">
            <NumberInput
              width="4em"
              step={0.25}
              minValue={0}
              maxValue={data.max_multiplier}
              value={data.multiplier}
              onChange={(value) => act('multiplier', { value })}
            />
          </LabeledList.Item>
          <LabeledList.Item label="Bot XP">
            <Button.Checkbox
              checked={!!data.bot_xp}
              onClick={() => act('bot_xp')}
            >
              {data.bot_xp ? 'On' : 'Off'}
            </Button.Checkbox>
          </LabeledList.Item>
        </LabeledList>
        <NoticeBox mt={1}>Settings reset when the server restarts.</NoticeBox>
      </Section>
      <XpBoost />
    </>
  );
};

export const ClashProgressionAdmin = () => {
  const [tab, setTab] = useState('player');
  return (
    <Window width={640} height={760}>
      <Window.Content scrollable>
        <Tabs>
          <Tabs.Tab
            icon="user"
            selected={tab === 'player'}
            onClick={() => setTab('player')}
          >
            Player
          </Tabs.Tab>
          <Tabs.Tab
            icon="sliders"
            selected={tab === 'server'}
            onClick={() => setTab('server')}
          >
            Server settings
          </Tabs.Tab>
        </Tabs>
        {tab === 'player' ? <PlayerTab /> : <ServerTab />}
      </Window.Content>
    </Window>
  );
};
