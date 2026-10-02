import type { BooleanLike } from 'common/react';
import { useBackend } from 'tgui/backend';
import {
  Button,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Table,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import type { CareerProgress } from './ClashStats';

interface PanelData {
  enabled: BooleanLike;
  multiplier: number;
  bot_xp: BooleanLike;
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
              {faction.insignia}, {faction.xp.toLocaleString('en-US')} XP
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
              {entry.xp.toLocaleString('en-US')} XP
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
              <Table.Cell collapsing textAlign="right">
                {weapon.mastered
                  ? 'Mastered'
                  : `${weapon.xp.toLocaleString('en-US')} XP`}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      </Section>
    </>
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
