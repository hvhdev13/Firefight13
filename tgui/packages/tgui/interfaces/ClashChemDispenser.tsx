import { toFixed } from 'common/math';
import type { BooleanLike } from 'common/react';
import { useBackend } from 'tgui/backend';
import {
  AnimatedNumber,
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import type { BeakerProps } from './common/BeakerContents';

type Mix = { name: string; contents: string };

type Data = {
  beakerTransferAmounts: number[];
  amount: number;
  energy: number;
  maxEnergy: number;
  isBeakerLoaded: BooleanLike;
  beakerContents: BeakerProps;
  beakerCurrentVolume: number | null;
  beakerMaxVolume: number | null;
  chemicals: { title: string; id: string }[];
  mixes: Mix[];
  templates: (Mix | null)[];
};

export const ClashChemDispenser = (props) => {
  const { act, data } = useBackend<Data>();
  const beakerTransferAmounts = data.beakerTransferAmounts || [];
  const beakerContents = data.beakerContents || [];
  const mixes = data.mixes || [];
  const templates = data.templates || [];
  const amountButtons = (icon: string, action: string, key: string) =>
    beakerTransferAmounts.map((amount) => (
      <Button
        key={amount}
        icon={icon}
        selected={action === 'amount' && amount === data.amount}
        onClick={() => act(action, { [key]: amount })}
      >
        {amount}
      </Button>
    ));
  return (
    <Window width={435} height={760}>
      <Window.Content scrollable>
        <Section title="Status">
          <LabeledList>
            <LabeledList.Item label="Energy">
              <ProgressBar value={data.energy / data.maxEnergy}>
                {toFixed(data.energy) + ' energy'}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section
          title="Dispense"
          buttons={amountButtons('plus', 'amount', 'target')}
        >
          <Box mr={-1}>
            {data.chemicals.map((chemical) => (
              <Button
                key={chemical.id}
                icon="arrow-alt-circle-down"
                width="129.5px"
                lineHeight={1.75}
                onClick={() => act('dispense', { reagent: chemical.id })}
              >
                {chemical.title}
              </Button>
            ))}
          </Box>
        </Section>
        <Section title="Mixes">
          <Box mr={-1}>
            {mixes.map((mix) => (
              <Button
                key={mix.name}
                icon="flask"
                width="129.5px"
                lineHeight={1.75}
                tooltip={`${mix.contents}. Fills ${data.amount}u in total.`}
                onClick={() => act('mix', { name: mix.name })}
              >
                {mix.name}
              </Button>
            ))}
          </Box>
        </Section>
        <Section title="Saved mixes">
          <Stack vertical>
            {templates.map((template, index) => (
              <Stack.Item key={index}>
                <Stack align="center">
                  <Stack.Item grow>
                    <Box bold>{template ? template.name : 'Empty slot'}</Box>
                    <Box color="label">
                      {template
                        ? template.contents
                        : 'Save a canister to keep its mix.'}
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="arrow-alt-circle-down"
                      disabled={!template}
                      onClick={() => act('template_fill', { index: index + 1 })}
                    >
                      Fill
                    </Button>
                    <Button
                      icon="save"
                      disabled={!data.isBeakerLoaded}
                      tooltip="Save the canister's current contents here"
                      onClick={() => act('template_save', { index: index + 1 })}
                    >
                      Save
                    </Button>
                    <Button.Confirm
                      icon="trash"
                      disabled={!template}
                      onClick={() =>
                        act('template_clear', { index: index + 1 })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
        <Section
          title="Canister"
          buttons={amountButtons('minus', 'remove', 'amount')}
        >
          <LabeledList>
            <LabeledList.Item
              label="Canister"
              buttons={
                !!data.isBeakerLoaded && (
                  <Button icon="eject" onClick={() => act('eject')}>
                    Eject
                  </Button>
                )
              }
            >
              {(data.isBeakerLoaded && (
                <>
                  <AnimatedNumber
                    initial={0}
                    value={data.beakerCurrentVolume || 0}
                  />
                  /{data.beakerMaxVolume} units
                </>
              )) || <NoticeBox info>No canister loaded!</NoticeBox>}
            </LabeledList.Item>
            <LabeledList.Item label="Contents">
              <Box color="label">
                {(!data.isBeakerLoaded && 'N/A') ||
                  (beakerContents.length === 0 && 'Nothing')}
              </Box>
              {beakerContents.map((chemical) => (
                <Box key={chemical.name} color="label">
                  <AnimatedNumber initial={0} value={chemical.volume} /> units
                  of {chemical.name}
                </Box>
              ))}
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
