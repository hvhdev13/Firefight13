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
  Stack,
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
  stats: [string, number][];
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
  doll_pending: BooleanLike;
  can_equip_now: BooleanLike;
  deploy_mode: BooleanLike;
  live: BooleanLike;
}

/** Worn gear down the left of the doll, carried gear down the right */
const LEFT_SLOTS = ['helmet', 'mask', 'armor', 'back'];
const RIGHT_SLOTS = ['primary', 'sidearm', 'grenade', 'belt'];
const POUCH_SLOTS = ['pouch_l', 'pouch_r'];
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
        {picked && <Box className="ClashKit__slotDot" />}
      </Box>
    </Tooltip>
  );
};

const StatChips = (props: { readonly stats: [string, number][] }) => {
  const { stats } = props;
  if (!stats?.length) return null;
  return (
    <Box className="ClashKit__stats">
      {stats.map(([label, value]) => (
        <Box as="span" key={label} className="ClashKit__stat">
          <Box as="span" className="ClashKit__statLabel">
            {label}
          </Box>
          {value}
        </Box>
      ))}
    </Box>
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
            <Icon name="box-open" size={1.4} />
          )}
        </Stack.Item>
        <Stack.Item grow>
          <Box className="ClashKit__optionName">
            {option?.name ?? label}
            {option && option.ammo > 0 && (
              <Box as="span" className="ClashKit__optionAmmo">
                ×{option.ammo}
              </Box>
            )}
          </Box>
          <Box className="ClashKit__optionBlurb">{option?.blurb ?? blurb}</Box>
          {option && <StatChips stats={option.stats} />}
        </Stack.Item>
        <Stack.Item className="ClashKit__optionCheck">
          {picked ? <Icon name="check" /> : disabled && <Icon name="ban" />}
        </Stack.Item>
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
    job,
    faction,
    kits,
    kit_index,
    active_index,
    choices,
    fits,
    doll,
    doll_pending,
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
  const isUpp = faction === 'UPP';
  const factionName = roles.find((group) => group.faction === faction)?.name;

  const roleOptions = roles.flatMap((group) =>
    group.jobs.map((title) => ({
      value: title,
      displayText: `${group.name} · ${title}`,
    })),
  );

  const tile = (id: string, small?: boolean, dimmed?: boolean) => (
    <SlotTile
      key={id}
      slot={slotById[id]}
      picked={findOption(menus, faction, id, choices[id])}
      selected={selectedSlot === id}
      small={small}
      dimmed={dimmed}
      onClick={() => setSelectedSlot(id)}
    />
  );

  return (
    <Window width={1080} height={700} theme={isUpp ? 'crtupp' : 'crtblue'}>
      <Window.Content
        className={classes(['ClashKit', isUpp && 'ClashKit--upp'])}
      >
        <Stack fill vertical>
          {/* Header */}
          <Stack.Item className="ClashKit__header">
            <Stack align="center">
              <Stack.Item className="ClashKit__badge">{factionName}</Stack.Item>
              <Stack.Item>
                <Dropdown
                  width="250px"
                  options={roleOptions}
                  selected={job}
                  displayText={job}
                  onSelected={(value) => act('role', { job: value })}
                />
              </Stack.Item>
              <Stack.Item grow>
                <Box className="ClashKit__kitTabs">
                  {kits.map((entry, index) => {
                    const number = index + 1;
                    return (
                      <Box
                        key={number}
                        className={classes([
                          'ClashKit__kitTab',
                          number === kit_index && 'ClashKit__kitTab--selected',
                        ])}
                        onClick={() => act('kit', { index: number })}
                      >
                        {number === active_index && (
                          <Icon name="star" className="ClashKit__kitStar" />
                        )}
                        {entry.name}
                        {entry.set > 0 && (
                          <Box as="span" className="ClashKit__kitCount">
                            {entry.set}
                          </Box>
                        )}
                      </Box>
                    );
                  })}
                </Box>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          {/* Body */}
          <Stack.Item grow>
            <Stack fill>
              {/* Doll with gear around it */}
              <Stack.Item className="ClashKit__dollPanel">
                <Box className="ClashKit__dollTitle">
                  {renaming ? (
                    <Input
                      autoFocus
                      width="180px"
                      value={kit?.name}
                      maxLength={24}
                      onEnter={(_, value) => {
                        act('rename', { name: value });
                        setRenaming(false);
                      }}
                      onEscape={() => setRenaming(false)}
                    />
                  ) : (
                    <Box
                      as="span"
                      className="ClashKit__kitName"
                      onClick={() => setRenaming(true)}
                    >
                      {kit?.name}
                      <Icon name="pen" className="ClashKit__kitNamePen" />
                    </Box>
                  )}
                  <Box className="ClashKit__dollSub">
                    {isActive ? (
                      <>
                        <Icon name="star" /> Spawn kit for {job}
                      </>
                    ) : (
                      `Not your spawn kit for ${job}`
                    )}
                  </Box>
                </Box>

                <Box className="ClashKit__dollGrid">
                  <Box className="ClashKit__slotColumn">
                    {LEFT_SLOTS.map((id) => tile(id))}
                  </Box>
                  <Box className="ClashKit__dollStage">
                    <Box
                      className={classes([
                        'ClashKit__dollFrame',
                        doll_pending && 'ClashKit__dollFrame--pending',
                      ])}
                    >
                      {doll ? (
                        <img
                          className="ClashKit__doll"
                          src={`data:image/png;base64,${doll}`}
                          alt=""
                        />
                      ) : (
                        <Icon
                          name="user"
                          size={5}
                          className="ClashKit__dollGhost"
                        />
                      )}
                      {!!doll_pending && (
                        <Icon
                          name="circle-notch"
                          spin
                          className="ClashKit__dollSpinner"
                        />
                      )}
                    </Box>
                    <Box className="ClashKit__pouchRow">
                      {POUCH_SLOTS.map((id) => tile(id, true))}
                    </Box>
                  </Box>
                  <Box className="ClashKit__slotColumn">
                    {RIGHT_SLOTS.map((id) => tile(id))}
                  </Box>
                </Box>

                <Box className="ClashKit__attachHeader">
                  {primary ? primary.name : 'Attachments'}
                  {!primary && (
                    <Box as="span" className="ClashKit__attachHint">
                      pick a primary first
                    </Box>
                  )}
                </Box>
                <Box className="ClashKit__attachRow">
                  {ATTACHMENT_SLOTS.map((id) => tile(id, true, !primary))}
                </Box>
              </Stack.Item>

              {/* Options */}
              <Stack.Item grow className="ClashKit__optionsPanel">
                <Box className="ClashKit__optionsHeader">
                  <Box as="span" className="ClashKit__optionsTitle">
                    {current?.name}
                  </Box>
                  <Box as="span" className="ClashKit__optionsCount">
                    {options.length} options
                  </Box>
                </Box>
                <Box className="ClashKit__optionsList">
                  <OptionRow
                    label={current?.attachment ? 'None' : 'Job issue'}
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
                </Box>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          {/* Footer */}
          <Stack.Item className="ClashKit__footer">
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
                    onClick={() => act('deploy')}
                  >
                    Deploy · {kit?.name}
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
