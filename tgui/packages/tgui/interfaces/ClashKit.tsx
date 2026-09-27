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

interface IssueItem {
  name: string;
  icon: string;
  icon_state: string;
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
  choices: Record<string, string>;
  issue: Record<string, IssueItem>;
  fits: string[];
  doll: string | null;
  doll_pending: BooleanLike;
  can_equip_now: BooleanLike;
  live: BooleanLike;
  deploy_state: 'lobby' | 'dead' | null;
  respawn_in: number;
  deploy_block: string | null;
  revivable: BooleanLike;
  hint: string | null;
}

/** Worn gear down the left of the doll, carried gear down the right */
const LEFT_SLOTS = ['helmet', 'mask', 'armor', 'back'];
const RIGHT_SLOTS = ['primary', 'sidearm', 'grenade', 'belt'];
const POUCH_SLOTS = ['pouch_l', 'pouch_r'];
const ATTACHMENT_SLOTS = ['rail', 'muzzle', 'under', 'stock'];

const clock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

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
  readonly issued?: IssueItem;
  readonly selected: boolean;
  readonly dimmed?: boolean;
  readonly small?: boolean;
  readonly onClick: () => void;
}) => {
  const { slot, picked, issued, selected, dimmed, small, onClick } = props;
  const shown = picked ?? issued;
  const tooltip = picked
    ? picked.name
    : issued
      ? `${issued.name} (job issue)`
      : `${slot.name}: nothing`;
  return (
    <Tooltip content={tooltip}>
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
        {!shown && slot.image && (
          <img
            className="ClashKit__slotArt"
            src={resolveAsset(slot.image)}
            alt=""
          />
        )}
        {shown ? (
          <DmIcon
            className={classes([
              'ClashKit__slotIcon',
              !picked && 'ClashKit__slotIcon--issue',
            ])}
            icon={shown.icon}
            icon_state={shown.icon_state}
            fallback={<Icon name="spinner" spin />}
          />
        ) : (
          !slot.image && <Icon className="ClashKit__slotEmpty" name="plus" />
        )}
        <Box className="ClashKit__slotLabel">{slot.name}</Box>
        {picked ? (
          <Box className="ClashKit__slotDot" />
        ) : (
          issued && <Box className="ClashKit__slotIssue">issue</Box>
        )}
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
  readonly issued?: IssueItem;
  readonly label?: string;
  readonly blurb?: string;
  readonly picked: boolean;
  readonly disabled?: boolean;
  readonly onClick: () => void;
}) => {
  const { option, issued, label, blurb, picked, disabled, onClick } = props;
  const art = option ?? issued;
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
          {art ? (
            <DmIcon
              icon={art.icon}
              icon_state={art.icon_state}
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
    choices,
    issue,
    fits,
    doll,
    doll_pending,
    can_equip_now,
    live,
    deploy_state,
    respawn_in,
    deploy_block,
    revivable,
    hint,
  } = data;

  const [selectedSlot, setSelectedSlot] = useState('primary');
  // The server sends the wait once; the client counts it down
  const [waitLeft, setWaitLeft] = useState(respawn_in);
  useEffect(() => {
    setWaitLeft(respawn_in);
    if (!respawn_in) return;
    const timer = setInterval(
      () => setWaitLeft((left) => Math.max(0, left - 1)),
      1000,
    );
    return () => clearInterval(timer);
  }, [respawn_in]);
  const [renaming, setRenaming] = useState(false);

  useEffect(() => {
    setRenaming(false);
  }, [kit_index, job]);

  const slotById = Object.fromEntries(slots.map((slot) => [slot.id, slot]));
  const kit = kits[kit_index - 1];
  const primary = findOption(menus, faction, 'primary', choices.primary);
  const current = slotById[selectedSlot];
  const options = menus[faction]?.[selectedSlot] ?? [];
  // Issue attachments only come with the issued gun
  const issueFor = (id: string) =>
    ATTACHMENT_SLOTS.includes(id) && choices.primary ? undefined : issue?.[id];
  const issued = issueFor(selectedSlot);
  const waiting = deploy_state === 'dead' && waitLeft > 0;
  const deployLabel = deploy_block
    ? 'Cannot deploy'
    : waiting
      ? `Deploy in ${clock(waitLeft)}`
      : `Deploy as ${job}`;
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
      issued={issueFor(id)}
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
                        {number === kit_index && (
                          <Icon name="check" className="ClashKit__kitStar" />
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
                  <Box className="ClashKit__dollSub">Your {job} class</Box>
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
                    issued={issued}
                    label={issued ? issued.name : 'Nothing'}
                    blurb={
                      issued
                        ? `What a ${job} is issued`
                        : current?.attachment
                          ? 'Leave this slot empty'
                          : `A ${job} gets nothing here`
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
              {!!live && (
                <Stack.Item>
                  <Button
                    icon="shirt"
                    disabled={!can_equip_now}
                    tooltip={
                      can_equip_now
                        ? 'Swap your gear for this kit now'
                        : 'Only inside your own base, as this role'
                    }
                    onClick={() => act('equip_now')}
                  >
                    Equip now
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item grow className="ClashKit__hint">
                {hint}
              </Stack.Item>
              <Stack.Item>
                <Button.Confirm
                  icon="rotate-left"
                  color="transparent"
                  confirmContent="Back to job issue?"
                  tooltip="Clear every pick in this kit"
                  onClick={() => act('reset')}
                >
                  Reset
                </Button.Confirm>
              </Stack.Item>
              {!!deploy_state && (
                <Stack.Item>
                  {revivable && !waiting && !deploy_block ? (
                    <Button.Confirm
                      className="ClashKit__deploy"
                      icon="person-running"
                      confirmIcon="triangle-exclamation"
                      confirmColor="average"
                      confirmContent="Body can be revived. Deploy anyway?"
                      onClick={() => act('deploy')}
                    >
                      {deployLabel}
                    </Button.Confirm>
                  ) : (
                    <Button
                      className={classes([
                        'ClashKit__deploy',
                        (waiting || deploy_block) &&
                          'ClashKit__deploy--waiting',
                      ])}
                      icon={waiting ? 'hourglass-half' : 'person-running'}
                      disabled={waiting || !!deploy_block}
                      tooltip={deploy_block || undefined}
                      onClick={() => act('deploy')}
                    >
                      {deployLabel}
                    </Button>
                  )}
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
