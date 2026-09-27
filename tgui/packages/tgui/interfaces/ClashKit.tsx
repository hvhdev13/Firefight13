import { type BooleanLike, classes } from 'common/react';
import { useEffect, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  DmIcon,
  Dropdown,
  Icon,
  Input,
  Section,
  Stack,
  Tabs,
  Tooltip,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

interface Slot {
  id: string;
  name: string;
  image: string | null;
  attachment: BooleanLike;
}

interface Option {
  id: string;
  name: string;
  blurb: string;
  icon: string;
  icon_state: string;
  ammo: number;
}

interface RoleGroup {
  faction: string;
  name: string;
  jobs: string[];
}

interface KitSummary {
  name: string;
  set: number;
}

interface StaticData {
  slots: Slot[];
  menus: Record<string, Record<string, Option[]>>;
  roles: RoleGroup[];
  kit_count: number;
}

interface Data extends StaticData {
  job: string;
  faction: string;
  kits: KitSummary[];
  kit_index: number;
  active_index: number;
  choices: Record<string, string>;
  fits: string[];
  doll: string | null;
  can_equip_now: BooleanLike;
  deploy_mode: BooleanLike;
  live: BooleanLike;
}

/** Slots laid out around the doll, in pairs. Attachments sit under the primary. */
const GEAR_SLOTS = [
  'helmet',
  'armor',
  'mask',
  'back',
  'belt',
  'primary',
  'pouch_l',
  'pouch_r',
  'sidearm',
];
const ATTACHMENT_SLOTS = ['rail', 'muzzle', 'under', 'stock'];

const findOption = (
  menus: Record<string, Record<string, Option[]>>,
  faction: string,
  slot: string,
  id: string | undefined,
): Option | undefined => {
  if (!id) return undefined;
  return menus[faction]?.[slot]?.find((option) => option.id === id);
};

const SlotTile = (props: {
  readonly slot: Slot;
  readonly picked?: Option;
  readonly selected: boolean;
  readonly dimmed?: boolean;
  readonly small?: boolean;
  readonly onClick: () => void;
}) => {
  const { slot, picked, selected, dimmed, small, onClick } = props;
  return (
    <Tooltip content={picked ? picked.name : `${slot.name}: job issue`}>
      <Box
        className={classes([
          'ClashKit__slot',
          small && 'ClashKit__slot--small',
          selected && 'ClashKit__slot--selected',
          dimmed && 'ClashKit__slot--dimmed',
          picked && 'ClashKit__slot--set',
        ])}
        onClick={onClick}
      >
        {slot.image && (
          <img
            className="ClashKit__slotArt"
            src={resolveAsset(slot.image)}
            alt=""
          />
        )}
        {picked ? (
          <DmIcon
            className="ClashKit__slotIcon"
            icon={picked.icon}
            icon_state={picked.icon_state}
            fallback={<Icon name="spinner" spin />}
          />
        ) : (
          !slot.image && <Icon className="ClashKit__slotEmpty" name="plus" />
        )}
        <Box className="ClashKit__slotLabel">{slot.name}</Box>
      </Box>
    </Tooltip>
  );
};

const OptionRow = (props: {
  readonly option?: Option;
  readonly label?: string;
  readonly blurb?: string;
  readonly picked: boolean;
  readonly disabled?: boolean;
  readonly onClick: () => void;
}) => {
  const { option, label, blurb, picked, disabled, onClick } = props;
  return (
    <Box
      className={classes([
        'ClashKit__option',
        picked && 'ClashKit__option--picked',
        disabled && 'ClashKit__option--disabled',
      ])}
      onClick={disabled ? undefined : onClick}
    >
      <Stack align="center">
        <Stack.Item className="ClashKit__optionIcon">
          {option ? (
            <DmIcon
              icon={option.icon}
              icon_state={option.icon_state}
              fallback={<Icon name="spinner" spin />}
            />
          ) : (
            <Icon name="user" size={1.5} />
          )}
        </Stack.Item>
        <Stack.Item grow>
          <Box className="ClashKit__optionName">{option?.name ?? label}</Box>
          <Box className="ClashKit__optionBlurb">
            {option?.blurb ?? blurb}
            {option && option.ammo > 0 ? ` · ${option.ammo} magazines` : ''}
          </Box>
        </Stack.Item>
        {picked && (
          <Stack.Item>
            <Icon name="check" />
          </Stack.Item>
        )}
      </Stack>
    </Box>
  );
};

export const ClashKit = () => {
  const { act, data } = useBackend<Data>();
  const {
    slots,
    menus,
    roles,
    kit_count,
    job,
    faction,
    kits,
    kit_index,
    active_index,
    choices,
    fits,
    doll,
    can_equip_now,
    deploy_mode,
    live,
  } = data;

  const [selectedSlot, setSelectedSlot] = useState('primary');
  const [renaming, setRenaming] = useState(false);

  useEffect(() => {
    setRenaming(false);
  }, [kit_index, job]);

  const slotById = Object.fromEntries(slots.map((slot) => [slot.id, slot]));
  const kit = kits[kit_index - 1];
  const primary = findOption(menus, faction, 'primary', choices.primary);
  const current = slotById[selectedSlot];
  const options = menus[faction]?.[selectedSlot] ?? [];
  const isActive = active_index === kit_index;
  const factionName = roles.find((group) => group.faction === faction)?.name;

  const roleOptions = roles.flatMap((group) =>
    group.jobs.map((title) => ({
      value: title,
      displayText: `${group.name} · ${title}`,
    })),
  );

  return (
    <Window
      width={1000}
      height={680}
      theme={faction === 'UPP' ? 'crtupp' : 'crtblue'}
    >
      <Window.Content className="ClashKit">
        <Stack fill vertical>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <Dropdown
                  width="260px"
                  options={roleOptions}
                  selected={job}
                  displayText={`${factionName} · ${job}`}
                  onSelected={(value) => act('role', { job: value })}
                />
              </Stack.Item>
              <Stack.Item grow>
                <Tabs>
                  {kits.map((entry, index) => (
                    <Tabs.Tab
                      key={index}
                      selected={index + 1 === kit_index}
                      icon={index + 1 === active_index ? 'star' : undefined}
                      onClick={() => act('kit', { index: index + 1 })}
                    >
                      {entry.name}
                      <Box as="span" className="ClashKit__tabCount">
                        {entry.set ? ` ${entry.set}` : ''}
                      </Box>
                    </Tabs.Tab>
                  ))}
                </Tabs>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item grow>
            <Stack fill>
              <Stack.Item width="236px">
                <Section fill title="Gear">
                  <Box className="ClashKit__slotGrid">
                    {GEAR_SLOTS.map((id) => (
                      <SlotTile
                        key={id}
                        slot={slotById[id]}
                        picked={findOption(menus, faction, id, choices[id])}
                        selected={selectedSlot === id}
                        onClick={() => setSelectedSlot(id)}
                      />
                    ))}
                  </Box>
                  <Box className="ClashKit__attachHeader">
                    {primary ? `${primary.name} attachments` : 'Attachments'}
                  </Box>
                  <Box className="ClashKit__attachGrid">
                    {ATTACHMENT_SLOTS.map((id) => (
                      <SlotTile
                        key={id}
                        small
                        slot={slotById[id]}
                        picked={findOption(menus, faction, id, choices[id])}
                        selected={selectedSlot === id}
                        dimmed={!primary}
                        onClick={() => setSelectedSlot(id)}
                      />
                    ))}
                  </Box>
                </Section>
              </Stack.Item>

              <Stack.Item width="220px">
                <Section fill className="ClashKit__dollSection">
                  <Stack fill vertical align="center" justify="center">
                    <Stack.Item>
                      {doll ? (
                        <img
                          className="ClashKit__doll"
                          src={`data:image/png;base64,${doll}`}
                          alt=""
                        />
                      ) : (
                        <Icon name="user" size={6} color="label" />
                      )}
                    </Stack.Item>
                    <Stack.Item className="ClashKit__dollName">
                      {renaming ? (
                        <Input
                          autoFocus
                          width="160px"
                          value={kit?.name}
                          maxLength={24}
                          onEnter={(_, value) => {
                            act('rename', { name: value });
                            setRenaming(false);
                          }}
                          onEscape={() => setRenaming(false)}
                        />
                      ) : (
                        <Button
                          color="transparent"
                          icon="pen"
                          tooltip="Rename"
                          onClick={() => setRenaming(true)}
                        >
                          {kit?.name}
                        </Button>
                      )}
                    </Stack.Item>
                    <Stack.Item className="ClashKit__dollMeta">
                      {factionName} · {job}
                      <br />
                      {isActive ? 'Spawns with this kit' : 'Not the spawn kit'}
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>

              <Stack.Item grow>
                <Section
                  fill
                  scrollable
                  title={current?.name}
                  buttons={
                    current?.attachment && !primary ? (
                      <Box color="label">Pick a primary first</Box>
                    ) : undefined
                  }
                >
                  <OptionRow
                    label="Job issue"
                    blurb={
                      current?.attachment
                        ? 'Nothing in this slot'
                        : 'Whatever the role hands out'
                    }
                    picked={!choices[selectedSlot]}
                    onClick={() => act('clear', { slot: selectedSlot })}
                  />
                  {options.map((option) => {
                    const unfit =
                      !!current?.attachment &&
                      (!primary || !fits.includes(option.id));
                    return (
                      <OptionRow
                        key={option.id}
                        option={option}
                        picked={choices[selectedSlot] === option.id}
                        disabled={unfit}
                        onClick={() =>
                          act('pick', { slot: selectedSlot, id: option.id })
                        }
                      />
                    );
                  })}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <Button
                  icon="star"
                  selected={isActive}
                  disabled={isActive}
                  onClick={() => act('set_active')}
                >
                  {isActive ? 'Spawn kit' : 'Use on spawn'}
                </Button>
              </Stack.Item>
              {!!live && (
                <Stack.Item>
                  <Button
                    icon="shirt"
                    disabled={!can_equip_now}
                    tooltip={
                      can_equip_now
                        ? 'Swap your gear for this kit'
                        : 'Only inside your own base, as this role'
                    }
                    onClick={() => act('equip_now')}
                  >
                    Equip now
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item grow />
              <Stack.Item>
                <Button.Confirm
                  icon="eraser"
                  color="transparent"
                  confirmContent="Clear kit?"
                  onClick={() => act('reset')}
                >
                  Reset
                </Button.Confirm>
              </Stack.Item>
              {!!deploy_mode && (
                <Stack.Item>
                  <Button
                    className="ClashKit__deploy"
                    icon="person-running"
                    color="good"
                    onClick={() => act('deploy')}
                  >
                    Deploy with {kit?.name}
                  </Button>
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
