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
  type: string;
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
  type?: string;
  icon: string;
  icon_state: string;
}

interface PackItem {
  type: string;
  name: string;
  icon: string;
  icon_state: string;
  extra: BooleanLike;
}

interface PackContainer {
  name: string;
  capacity: string;
  items: PackItem[];
  type: string;
  shells?: string[];
  fill?: string;
}

interface Extra {
  id: string;
  name: string;
  status: 'ok' | 'room' | 'points' | 'gone' | 'locked' | 'pending';
}

interface ShopItem {
  id: string;
  name: string;
  cost: number;
  pool: 'points' | 'snowflake';
  icon: string;
  icon_state: string;
}

interface ShopSection {
  name: string;
  items: ShopItem[];
}

interface KitSummary {
  name: string;
  set: number;
}

interface LevelBar {
  to_next: number;
  fill: number;
}

interface GunProgress {
  name: string;
  level: number;
  max: number;
  mastery: number;
  mastered: BooleanLike;
  next?: string;
  kills_to_go?: number;
}

interface CarrierProgress {
  family: string;
  step: number;
  steps: number;
  next?: string;
  xp_to_go?: number;
}

interface KitProgress {
  side: string;
  faction_level: number;
  insignia: string;
  faction_bar: LevelBar;
  class?: string;
  class_level: number;
  class_bar: LevelBar;
  next?: string;
  locks: Record<string, string>;
  fresh: string[];
  role_locks: Record<string, string>;
  shop_locks: Record<string, string>;
  gun?: GunProgress;
  carriers: CarrierProgress[];
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
  gun: string | null;
  doll_pending: BooleanLike;
  can_equip_now: BooleanLike;
  live: BooleanLike;
  deploy_state: 'lobby' | 'dead' | null;
  respawn_in: number;
  deploy_block: string | null;
  revivable: BooleanLike;
  hint: string | null;
  pack: PackContainer[];
  extras: Extra[];
  removed: { type: string; name: string }[];
  shop: ShopSection[];
  budget: [number, number];
  spent: { points: number; snowflake: number };
  progress?: KitProgress;
}

type Tab = 'gear' | 'pack' | 'shop';

const EXTRA_PROBLEMS: Record<string, string> = {
  room: 'No room, will not be packed',
  points: 'Not enough points, will not be bought',
  gone: 'No longer sold to this role',
  locked: 'Locked for your class level, will not be bought',
};

const xpText = (value: number) => value.toLocaleString('en-US');

const ProgressBar = (props: {
  readonly label: string;
  readonly bar: LevelBar;
}) => {
  const { label, bar } = props;
  return (
    <Box className="ClashKit__level">
      <Box className="ClashKit__levelLabel">{label}</Box>
      <Box className="ClashKit__levelBar">
        <Box
          className="ClashKit__levelFill"
          style={{ width: `${Math.round(bar.fill * 100)}%` }}
        />
      </Box>
      <Box className="ClashKit__levelNext">
        {bar.to_next ? `${xpText(bar.to_next)} XP to next` : 'Max level'}
      </Box>
    </Box>
  );
};

const ProgressStrip = (props: { readonly progress: KitProgress }) => {
  const { progress } = props;
  return (
    <Box className="ClashKit__progress">
      <ProgressBar
        label={`${progress.side} level ${progress.faction_level} · ${progress.insignia}`}
        bar={progress.faction_bar}
      />
      {progress.class && (
        <ProgressBar
          label={`${progress.class} level ${progress.class_level}`}
          bar={progress.class_bar}
        />
      )}
      {progress.next && (
        <Box className="ClashKit__progressNext">{progress.next}</Box>
      )}
    </Box>
  );
};

const GunPanel = (props: { readonly gun: GunProgress }) => {
  const { gun } = props;
  return (
    <Box className="ClashKit__gunProgress">
      <Box>
        {gun.name} level <b>{gun.level}</b> / {gun.max}
        {gun.next && (
          <Box as="span" className="ClashKit__optionBlurb">
            {' '}
            · Next: {gun.next} in about {gun.kills_to_go} kills
          </Box>
        )}
      </Box>
      <Box className="ClashKit__levelBar">
        <Box
          className="ClashKit__levelFill ClashKit__levelFill--mastery"
          style={{ width: `${Math.round(gun.mastery * 100)}%` }}
        />
      </Box>
      <Box className="ClashKit__optionBlurb">
        {gun.mastered
          ? 'Mastered'
          : `Mastery ${Math.floor(gun.mastery * 100)}%`}
      </Box>
    </Box>
  );
};

const CarrierList = (props: { readonly carriers: CarrierProgress[] }) => (
  <Box className="ClashKit__packHolder">
    <Box className="ClashKit__packHead">Ammo carriers</Box>
    {props.carriers.map((carrier) => (
      <Box key={carrier.family} className="ClashKit__packItem">
        <Stack align="center">
          <Stack.Item grow>
            {carrier.family}
            <Box as="span" className="ClashKit__optionAmmo">
              step {carrier.step} / {carrier.steps}
            </Box>
          </Stack.Item>
          <Stack.Item className="ClashKit__optionBlurb">
            {carrier.next
              ? `${carrier.next} in ${xpText(carrier.xp_to_go ?? 0)} XP`
              : 'All unlocked'}
          </Stack.Item>
        </Stack>
      </Box>
    ))}
  </Box>
);

const ItemIcon = (props: { readonly icon: string; readonly state: string }) => (
  <Box className="ClashKit__optionIcon">
    <DmIcon
      icon={props.icon}
      icon_state={props.state}
      fallback={<Icon name="spinner" spin />}
    />
  </Box>
);

const PackView = () => {
  const { act, data } = useBackend<Data>();
  const { pack, extras, removed, doll_pending, progress } = data;
  const problems = extras
    .map((extra, index) => ({ ...extra, index: index + 1 }))
    .filter((extra) => EXTRA_PROBLEMS[extra.status]);
  return (
    <>
      {progress && <CarrierList carriers={progress.carriers} />}
      {!!doll_pending && (
        <Box className="ClashKit__packNote">
          <Icon name="circle-notch" spin /> Repacking...
        </Box>
      )}
      {problems.map((extra) => (
        <Box key={extra.index} className="ClashKit__option ClashKit__packWarn">
          <Stack align="center">
            <Stack.Item grow>
              <Box className="ClashKit__optionName">{extra.name}</Box>
              <Box className="ClashKit__optionBlurb">
                {EXTRA_PROBLEMS[extra.status]}
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="xmark"
                color="transparent"
                tooltip="Take it off the list"
                onClick={() => act('unbuy', { index: extra.index })}
              />
            </Stack.Item>
          </Stack>
        </Box>
      ))}
      {pack.map((holder, holderIndex) => (
        <Box key={holderIndex} className="ClashKit__packHolder">
          <Box className="ClashKit__packHead">
            <Box as="span">{holder.name}</Box>
            {!!holder.shells && (
              <Dropdown
                width="110px"
                options={holder.shells}
                selected={holder.fill}
                displayText={holder.fill}
                onSelected={(value) =>
                  act('fill', { container: holder.type, shell: value })
                }
              />
            )}
            <Box as="span" className="ClashKit__optionsCount">
              {holder.capacity}
            </Box>
          </Box>
          {holder.items.length ? (
            holder.items.map((item, itemIndex) => (
              <Box key={itemIndex} className="ClashKit__packItem">
                <Stack align="center">
                  <Stack.Item>
                    <ItemIcon icon={item.icon} state={item.icon_state} />
                  </Stack.Item>
                  <Stack.Item grow>
                    {item.name}
                    {!!item.extra && (
                      <Box as="span" className="ClashKit__packBought">
                        bought
                      </Box>
                    )}
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="xmark"
                      color="transparent"
                      tooltip={
                        item.extra
                          ? 'Return it and get the points back'
                          : 'Leave it behind to make room'
                      }
                      onClick={() =>
                        act('drop_item', {
                          type: item.type,
                          extra: item.extra ? 1 : 0,
                        })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Box>
            ))
          ) : (
            <Box className="ClashKit__packEmpty">Empty</Box>
          )}
        </Box>
      ))}
      {!pack.length && !doll_pending && (
        <Box className="ClashKit__packEmpty">
          This kit has nothing to pack into.
        </Box>
      )}
      {!!removed.length && (
        <Box className="ClashKit__packHolder">
          <Box className="ClashKit__packHead">Left behind</Box>
          {removed.map((item, index) => (
            <Box key={index} className="ClashKit__packItem">
              <Stack align="center">
                <Stack.Item grow>{item.name}</Stack.Item>
                <Stack.Item>
                  <Button
                    icon="rotate-left"
                    color="transparent"
                    tooltip="Pack it again"
                    onClick={() => act('restore_item', { type: item.type })}
                  />
                </Stack.Item>
              </Stack>
            </Box>
          ))}
        </Box>
      )}
    </>
  );
};

const pointsLeft = (data: Data) => ({
  points: data.budget[0] - (data.spent.points ?? 0),
  snowflake: data.budget[1] - (data.spent.snowflake ?? 0),
});

const ShopView = () => {
  const { act, data } = useBackend<Data>();
  const { shop, budget, extras, progress } = data;
  const [search, setSearch] = useState('');
  const left = pointsLeft(data);
  const owned: Record<string, number> = {};
  for (const extra of extras) {
    owned[extra.id] = (owned[extra.id] ?? 0) + 1;
  }
  const query = search.trim().toLowerCase();
  const sections = shop
    .map((section) => ({
      ...section,
      items: query
        ? section.items.filter((item) =>
            item.name.toLowerCase().includes(query),
          )
        : section.items,
    }))
    .filter((section) => section.items.length);
  const usesSnowflake = shop.some((section) =>
    section.items.some((item) => item.pool === 'snowflake'),
  );
  if (!shop.length) {
    return (
      <Box className="ClashKit__packEmpty">
        This role has nothing to buy with points.
      </Box>
    );
  }
  return (
    <>
      <Box className="ClashKit__shopPoints">
        Points left: <b>{left.points}</b> / {budget[0]}
        {usesSnowflake && (
          <Box as="span" ml={2}>
            Specialist points: <b>{left.snowflake}</b> / {budget[1]}
          </Box>
        )}
        <Box className="ClashKit__optionBlurb">
          Bought gear is packed at spawn. What you do not spend stays for the
          vendors.
        </Box>
        <Input
          fluid
          mt={1}
          placeholder="Search"
          value={search}
          onInput={(_, value) => setSearch(value)}
        />
      </Box>
      {!sections.length && (
        <Box className="ClashKit__packEmpty">Nothing matches.</Box>
      )}
      {sections.map((section) => (
        <Box key={section.name} className="ClashKit__packHolder">
          <Box className="ClashKit__packHead">{section.name}</Box>
          {section.items.map((item) => {
            const short = left[item.pool] < item.cost;
            const lock = progress?.shop_locks[item.id];
            const count = owned[item.id] ?? 0;
            return (
              <Box key={item.id} className="ClashKit__packItem">
                <Stack align="center">
                  <Stack.Item>
                    <ItemIcon icon={item.icon} state={item.icon_state} />
                  </Stack.Item>
                  <Stack.Item grow>
                    {item.name}
                    {lock && (
                      <Box className="ClashKit__optionLock">
                        <Icon name="lock" /> {lock}
                      </Box>
                    )}
                    {count > 0 && (
                      <Box as="span" className="ClashKit__packBought">
                        ×{count}
                      </Box>
                    )}
                  </Stack.Item>
                  <Stack.Item className="ClashKit__shopCost">
                    {item.cost}
                    {item.pool === 'snowflake' ? ' sp' : ''}
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="minus"
                      disabled={!count}
                      tooltip="Return one"
                      onClick={() => act('unbuy_id', { id: item.id })}
                    />
                    <Button
                      icon="cart-plus"
                      disabled={short || !!lock}
                      tooltip={
                        lock ||
                        (short ? 'Not enough points' : 'Buy and pack it')
                      }
                      onClick={() => act('buy', { id: item.id })}
                    />
                  </Stack.Item>
                </Stack>
              </Box>
            );
          })}
        </Box>
      ))}
    </>
  );
};

const LEFT_SLOTS = ['helmet', 'mask', 'armor', 'back'];
const RIGHT_SLOTS = ['primary', 'sidearm', 'grenade', 'belt'];
const POUCH_SLOTS = ['pouch_l', 'webbing', 'pouch_r'];
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
  readonly lock?: string;
  readonly fresh?: boolean;
  readonly onClick: () => void;
}) => {
  const {
    slot,
    picked,
    issued,
    selected,
    dimmed,
    small,
    lock,
    fresh,
    onClick,
  } = props;
  const shown = picked ?? issued;
  const tooltip = lock
    ? `${picked?.name}: locked, ${lock}. The starting item is used at spawn.`
    : picked
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
          (dimmed || lock) && 'ClashKit__slot--dimmed',
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
        {fresh && <Box className="ClashKit__slotNew">new</Box>}
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
  readonly issueTag?: boolean;
  readonly lock?: string;
  readonly fresh?: boolean;
  readonly onClick: () => void;
}) => {
  const {
    option,
    issued,
    label,
    blurb,
    picked,
    disabled,
    issueTag,
    lock,
    fresh,
    onClick,
  } = props;
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
            {issueTag && (
              <Box as="span" className="ClashKit__optionIssue">
                issued
              </Box>
            )}
            {fresh && (
              <Box as="span" className="ClashKit__optionNew">
                new
              </Box>
            )}
            {option && option.ammo > 0 && (
              <Box as="span" className="ClashKit__optionAmmo">
                ×{option.ammo}
              </Box>
            )}
          </Box>
          <Box className="ClashKit__optionBlurb">{option?.blurb ?? blurb}</Box>
          {lock && (
            <Box className="ClashKit__optionLock">
              <Icon name="lock" /> {lock}
            </Box>
          )}
          {option && <StatChips stats={option.stats} />}
        </Stack.Item>
        <Stack.Item className="ClashKit__optionCheck">
          {picked ? (
            <Icon name="check" />
          ) : lock ? (
            <Icon name="lock" />
          ) : (
            disabled && <Icon name="ban" />
          )}
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
    progress,
  } = data;

  const [selectedSlot, setSelectedSlot] = useState('primary');
  const [tab, setTab] = useState<Tab>('gear');
  const left = pointsLeft(data);
  const packProblems = data.extras.filter(
    (extra) => EXTRA_PROBLEMS[extra.status],
  ).length;
  const { shop } = data;
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
  const issueFor = (id: string) =>
    ATTACHMENT_SLOTS.includes(id) && choices.primary ? undefined : issue?.[id];
  const issued = issueFor(selectedSlot);
  const issuedOption = issued?.type
    ? options.find((option) => option.type === issued.type)
    : undefined;
  const waiting = deploy_state === 'dead' && waitLeft > 0;
  const deployLabel = deploy_block
    ? 'Cannot deploy'
    : waiting
      ? `Deploy in ${clock(waitLeft)}`
      : `Deploy as ${job}`;
  const isUpp = faction === 'UPP';
  const roleOptions = (
    roles.find((group) => group.faction === faction)?.jobs ?? []
  ).map((title) => ({
    value: title,
    displayText: progress?.role_locks[title]
      ? `${title} (${progress.role_locks[title]})`
      : title,
  }));
  const fresh = progress?.fresh ?? [];
  const locks = progress?.locks ?? {};
  const [newHere, setNewHere] = useState<string[]>([]);
  useEffect(() => {
    const ids = options
      .filter((option) => fresh.includes(option.id))
      .map((option) => option.id);
    setNewHere(ids);
    if (ids.length) {
      act('seen', { ids });
    }
  }, [selectedSlot, job]);

  const tile = (id: string, small?: boolean, dimmed?: boolean) => (
    <SlotTile
      key={id}
      slot={slotById[id]}
      picked={findOption(menus, faction, id, choices[id])}
      issued={issueFor(id)}
      selected={selectedSlot === id}
      small={small}
      dimmed={dimmed}
      lock={choices[id] ? locks[choices[id]] : undefined}
      fresh={
        selectedSlot !== id &&
        !!menus[faction]?.[id]?.some((option) => fresh.includes(option.id))
      }
      onClick={() => {
        setSelectedSlot(id);
        setTab('gear');
      }}
    />
  );

  return (
    <Window width={1080} height={800} theme={isUpp ? 'crtred' : 'crtblue'}>
      <Window.Content
        className={classes(['ClashKit', isUpp && 'ClashKit--upp'])}
      >
        <Stack fill vertical>
          <Stack.Item className="ClashKit__header">
            {progress && <ProgressStrip progress={progress} />}
            <Stack align="center">
              <Stack.Item className="ClashKit__headLeft">
                <Box className="ClashKit__sides">
                  {roles.map((group) => (
                    <Box
                      key={group.faction}
                      className={classes([
                        'ClashKit__side',
                        group.faction === faction && 'ClashKit__side--selected',
                      ])}
                      onClick={() => act('side', { faction: group.faction })}
                    >
                      {group.name}
                    </Box>
                  ))}
                </Box>
                <Dropdown
                  width="250px"
                  options={roleOptions}
                  selected={job}
                  displayText={job}
                  onSelected={(value) => act('role', { job: value })}
                />
              </Stack.Item>
              <Stack.Item grow basis={0}>
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
                        <Box as="span" className="ClashKit__kitLabel">
                          {entry.name}
                        </Box>
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

          <Stack.Item grow>
            <Stack fill>
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
                    Your {job} class
                    {kits.length > 1 && (
                      <Dropdown
                        ml={1}
                        width="150px"
                        options={kits
                          .map((entry, index) => ({
                            value: String(index + 1),
                            displayText: entry.name,
                          }))
                          .filter((_, index) => index + 1 !== kit_index)}
                        selected=""
                        displayText="Copy from..."
                        onSelected={(value) => act('copy', { index: value })}
                      />
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
                <Box
                  className={classes([
                    'ClashKit__gunFrame',
                    doll_pending && 'ClashKit__gunFrame--pending',
                  ])}
                >
                  {data.gun ? (
                    <img
                      className="ClashKit__gun"
                      src={`data:image/png;base64,${data.gun}`}
                      alt=""
                    />
                  ) : (
                    <Box className="ClashKit__gunEmpty">No primary</Box>
                  )}
                </Box>
                {progress?.gun && <GunPanel gun={progress.gun} />}
              </Stack.Item>

              <Stack.Item grow className="ClashKit__optionsPanel">
                <Box className="ClashKit__tabs">
                  {(
                    [
                      ['gear', current?.name ?? 'Gear'],
                      [
                        'pack',
                        packProblems ? `Pack (${packProblems}!)` : 'Pack',
                      ],
                      [
                        'shop',
                        shop.length ? `Shop · ${left.points} pts` : 'Shop',
                      ],
                    ] as [Tab, string][]
                  ).map(([id, label]) => (
                    <Box
                      key={id}
                      className={classes([
                        'ClashKit__tab',
                        tab === id && 'ClashKit__tab--selected',
                      ])}
                      onClick={() => setTab(id)}
                    >
                      {label}
                    </Box>
                  ))}
                  {tab === 'gear' && (
                    <Box as="span" className="ClashKit__optionsCount">
                      {options.length} options
                    </Box>
                  )}
                </Box>
                {tab === 'pack' && (
                  <Box className="ClashKit__optionsList">
                    <PackView />
                  </Box>
                )}
                {tab === 'shop' && (
                  <Box className="ClashKit__optionsList">
                    <ShopView />
                  </Box>
                )}
                <Box
                  className="ClashKit__optionsList"
                  style={{ display: tab === 'gear' ? undefined : 'none' }}
                >
                  {!issuedOption && (
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
                  )}
                  {options.map((option) => {
                    const unfit =
                      !!current?.attachment &&
                      (!primary || !fits.includes(option.id));
                    const isIssue = option.id === issuedOption?.id;
                    const lock = isIssue ? undefined : locks[option.id];
                    return (
                      <OptionRow
                        key={option.id}
                        option={option}
                        issueTag={isIssue}
                        lock={lock}
                        fresh={
                          fresh.includes(option.id) ||
                          newHere.includes(option.id)
                        }
                        picked={
                          choices[selectedSlot] === option.id ||
                          (isIssue && !choices[selectedSlot])
                        }
                        disabled={(unfit && !isIssue) || !!lock}
                        onClick={() =>
                          isIssue
                            ? act('clear', { slot: selectedSlot })
                            : act('pick', { slot: selectedSlot, id: option.id })
                        }
                      />
                    );
                  })}
                </Box>
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item className="ClashKit__footer">
            <Stack align="center">
              <Stack.Item grow basis={0}>
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
                </Stack>
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
              <Stack.Item grow basis={0} textAlign="right">
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
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
