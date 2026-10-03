import type { BooleanLike } from 'common/react';
import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Table,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import type { CareerProgress } from './ClashStats';

interface BoostData {
  active: BooleanLike;
  multiplier: number;
  left: string | null;
  started_by: string | null;
  max: number;
  max_hours: number;
  max_rounds: number;
}

interface PanelData {
  enabled: BooleanLike;
  multiplier: number;
  bot_xp: BooleanLike;
  boost: BoostData;
  ckey: string | null;
  progress: CareerProgress | null;
  max_multiplier: number;
  level_cap: number;
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

const PlayerProgress = (props: { readonly progress: CareerProgress }) => {
  const { data } = useBackend<PanelData>();
  const { progress } = props;
  return (
    <>
      <Section title="Faction and class levels">
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
            </LabeledList.Item>
          ))}
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
            </LabeledList.Item>
          ))}
        </LabeledList>
      </Section>
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

export const ClashProgressionAdmin = () => {
  const { act, data } = useBackend<PanelData>();
  return (
    <Window width={520} height={680}>
      <Window.Content scrollable>
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
        <Section title="Player">
          <Input
            fluid
            placeholder="Ckey, then Enter"
            value={data.ckey ?? ''}
            onEnter={(_, value) => act('lookup', { ckey: value })}
          />
        </Section>
        {data.progress ? (
          <PlayerProgress progress={data.progress} />
        ) : (
          data.ckey && <NoticeBox>No progression for {data.ckey}.</NoticeBox>
        )}
      </Window.Content>
    </Window>
  );
};
