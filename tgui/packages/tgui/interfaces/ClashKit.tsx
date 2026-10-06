import { type BooleanLike, classes } from 'common/react';
import { type ReactNode, useEffect, useState } from 'react';
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
import { fetchRetry } from 'tgui/http';
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
  only_class: string | null;
  contents?: string[];
}

interface RoleGroup {
  faction: string;
  name: string;
  jobs: string[];
}

interface IssueItem {
  name: string;
  desc?: string;
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
  contents?: string[];
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
  contents?: string[];
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
  ranks: Record<string, number>;
  fresh: string[];
  role_locks: Record<string, string>;
  shop_locks: Record<string, string>;
  gun?: GunProgress;
  sidearm_gun?: GunProgress;
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
  sidearm: string | null;
  doll_pending: BooleanLike;
  deploy_state: 'lobby' | 'dead' | null;
  respawn_in: number;
  deploy_block: string | null;
  revivable: BooleanLike;
  sentry_slot: BooleanLike;
  job_class: string;
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

const AttachmentGroup = (props: {
  readonly name?: string;
  readonly sidearm: boolean;
  readonly tiles: ReactNode[];
}) => {
  const { name, sidearm, tiles } = props;
  return (
    <Box>
      <Box className="ClashKit__attachHeader">
        {name ?? 'Attachments'}
        {!name && (
          <Box as="span" className="ClashKit__attachHint">
            {sidearm ? 'pick a sidearm first' : 'pick a primary first'}
          </Box>
        )}
      </Box>
      <Box className="ClashKit__attachRow">{tiles}</Box>
    </Box>
  );
};

const WeaponPreview = (props: {
  readonly image: string | null;
  readonly sidearm: boolean;
  readonly pending: boolean;
  readonly progress?: GunProgress;
}) => {
  const { image, sidearm, pending, progress } = props;
  return (
    <>
      <Box
        className={classes([
          'ClashKit__gunFrame',
          pending && 'ClashKit__gunFrame--pending',
        ])}
      >
        {image ? (
          <FitSprite
            className="ClashKit__gun"
            src={`data:image/png;base64,${image}`}
            fitWidth={392}
            fitHeight={100}
            maxScale={sidearm ? SIDEARM_SCALE : PRIMARY_SCALE}
            whole
          />
        ) : (
          <Box className="ClashKit__gunEmpty">
            {sidearm ? 'No sidearm' : 'No primary'}
          </Box>
        )}
      </Box>
      {progress && <GunPanel gun={progress} />}
    </>
  );
};

const CarrierList = (props: { readonly carriers: CarrierProgress[] }) => (
  <Box className="ClashKit__packHolder">
    <Box className="ClashKit__packHead">Ammo carriers</Box>
    {props.carriers.map((carrier) => (
      <Box key={carrier.family} className="ClashKit__packItem">
        <Stack align="center">
          <Stack.Item grow>
            {carrier.family} ammo
            <Box as="span" className="ClashKit__optionAmmo">
              {carrier.step} of {carrier.steps} carriers unlocked
            </Box>
          </Stack.Item>
          <Stack.Item className="ClashKit__optionBlurb">
            {carrier.next
              ? `Next: ${carrier.next} in ${xpText(carrier.xp_to_go ?? 0)} XP`
              : 'All unlocked'}
          </Stack.Item>
        </Stack>
      </Box>
    ))}
  </Box>
);

type Sprite = {
  url: string;
  width: number;
  height: number;
};

let iconRefs: Promise<Record<string, string>> | undefined;

const loadIconRefs = () => {
  if (!iconRefs) {
    iconRefs = fetchRetry(resolveAsset('icon_ref_map.json')).then((response) =>
      response.json(),
    );
    iconRefs.catch(() => {
      iconRefs = undefined;
    });
  }
  return iconRefs;
};

const spriteCache = new Map<string, Promise<Sprite>>();

const loadImage = (source: string, attempt = 0): Promise<HTMLImageElement> =>
  new Promise((resolve, reject) => {
    const image = new window.Image();
    image.onload = () => resolve(image);
    image.onerror = () => {
      if (attempt >= 4) {
        reject(new Error(`Could not load ${source}`));
        return;
      }
      setTimeout(
        () => loadImage(source, attempt + 1).then(resolve, reject),
        1000,
      );
    };
    image.src = attempt ? `${source}&attempt=${attempt}` : source;
  });

const cropSprite = async (
  source: string,
  fitWidth: number,
  fitHeight: number,
  maxScale: number,
  whole: boolean,
): Promise<Sprite> => {
  const image = await loadImage(source);
  const fullWidth = image.naturalWidth;
  const fullHeight = image.naturalHeight;
  const canvas = document.createElement('canvas');
  canvas.width = fullWidth;
  canvas.height = fullHeight;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('No canvas');
  context.drawImage(image, 0, 0);
  const pixels = context.getImageData(0, 0, fullWidth, fullHeight).data;
  let left = fullWidth;
  let right = -1;
  let top = fullHeight;
  let bottom = -1;
  for (let y = 0; y < fullHeight; y++) {
    for (let x = 0; x < fullWidth; x++) {
      if (pixels[(y * fullWidth + x) * 4 + 3] < 16) continue;
      left = Math.min(left, x);
      right = Math.max(right, x);
      top = Math.min(top, y);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < 0) throw new Error('Empty sprite');
  const width = right - left + 1;
  const height = bottom - top + 1;
  const cropped = document.createElement('canvas');
  cropped.width = width;
  cropped.height = height;
  cropped
    .getContext('2d')
    ?.drawImage(canvas, left, top, width, height, 0, 0, width, height);
  const fit = Math.min(fitWidth / width, fitHeight / height, maxScale);
  const scale = whole ? Math.max(1, Math.floor(fit)) : fit;
  return {
    url: cropped.toDataURL(),
    width: Math.round(width * scale),
    height: Math.round(height * scale),
  };
};

const FitSprite = (props: {
  readonly src?: string;
  readonly fitWidth: number;
  readonly fitHeight: number;
  readonly maxScale?: number;
  readonly whole?: boolean;
  readonly className?: string;
  readonly fallback?: ReactNode;
}) => {
  const {
    src,
    fitWidth,
    fitHeight,
    maxScale = 8,
    whole = false,
    className,
    fallback = null,
  } = props;
  const [sprite, setSprite] = useState<Sprite | null>(null);
  useEffect(() => {
    if (!src) return;
    let live = true;
    const key = `${fitWidth}x${fitHeight}x${maxScale}${whole}|${src}`;
    let job = spriteCache.get(key);
    if (!job) {
      job = cropSprite(src, fitWidth, fitHeight, maxScale, whole);
      spriteCache.set(key, job);
      job.catch(() => spriteCache.delete(key));
    }
    job.then(
      (result) => live && setSprite(result),
      () => live && setSprite({ url: src, width: fitWidth, height: fitHeight }),
    );
    return () => {
      live = false;
    };
  }, [src, fitWidth, fitHeight, maxScale, whole]);
  if (!sprite) return fallback;
  return (
    <img
      className={className}
      src={sprite.url}
      style={{
        width: `${sprite.width}px`,
        height: `${sprite.height}px`,
        imageRendering: 'pixelated',
        objectFit: 'contain',
      }}
      alt=""
    />
  );
};

const IconSprite = (props: {
  readonly icon: string;
  readonly state: string;
  readonly fitWidth: number;
  readonly fitHeight: number;
}) => {
  const { icon, state, fitWidth, fitHeight } = props;
  const [src, setSrc] = useState<string>();
  useEffect(() => {
    let live = true;
    loadIconRefs().then((refs) => {
      if (live && refs[icon]) {
        setSrc(`${refs[icon]}?state=${state}&dir=2&movement=false&frame=1`);
      }
    });
    return () => {
      live = false;
    };
  }, [icon, state]);
  return (
    <FitSprite
      src={src}
      fitWidth={fitWidth}
      fitHeight={fitHeight}
      maxScale={3}
      fallback={<Icon name="spinner" spin />}
    />
  );
};

const ContentsHint = (props: { readonly contents?: string[] }) => {
  const { contents } = props;
  if (!contents?.length) return null;
  return (
    <Tooltip
      content={
        <>
          <Box bold>Contains</Box>
          {contents.map((line) => (
            <Box key={line}>{line}</Box>
          ))}
        </>
      }
    >
      <Icon name="circle-exclamation" className="ClashKit__contentsHint" />
    </Tooltip>
  );
};

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
                    <ContentsHint contents={item.contents} />
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
                    <ContentsHint contents={item.contents} />
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

const LEFT_SLOTS = ['helmet', 'eyes', 'mask', 'armor', 'back'];
const RIGHT_SLOTS = ['primary', 'sidearm', 'grenade', 'belt'];
const POUCH_SLOTS = ['pouch_l', 'webbing', 'pouch_r'];
const ATTACHMENT_SLOTS = ['rail', 'muzzle', 'under', 'stock'];
const SIDE_ATTACHMENT_SLOTS = [
  'side_rail',
  'side_muzzle',
  'side_under',
  'side_stock',
];
const PRIMARY_SCALE = 5;
const SIDEARM_SCALE = 8;

type WeaponView = 'primary' | 'sidearm';

const issueForSlot = (
  id: string,
  choices: Record<string, string>,
  issue: Record<string, IssueItem>,
) => {
  if (ATTACHMENT_SLOTS.includes(id) && choices.primary) return undefined;
  if (SIDE_ATTACHMENT_SLOTS.includes(id) && choices.sidearm) return undefined;
  return issue?.[id];
};

const weaponViewFor = (id: string): WeaponView | null => {
  if (id === 'sidearm' || SIDE_ATTACHMENT_SLOTS.includes(id)) return 'sidearm';
  if (id === 'primary' || ATTACHMENT_SLOTS.includes(id)) return 'primary';
  return null;
};
const PERK_SLOTS = ['class_perk', 'general_perk'];

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
  readonly dense?: boolean;
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
    dense,
    lock,
    fresh,
    onClick,
  } = props;
  const shown = picked ?? issued;
  const perk = PERK_SLOTS.includes(slot.id);
  const tooltip = lock
    ? `${picked?.name}: locked, ${lock}. ${perk ? 'You spawn without it.' : 'The starting item is used at spawn.'}`
    : picked
      ? perk
        ? `${picked.name}: ${picked.blurb}`
        : picked.name
      : issued
        ? issued.name
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
          <Box className="ClashKit__slotIcon">
            <IconSprite
              icon={shown.icon}
              state={shown.icon_state}
              fitWidth={small ? 52 : 60}
              fitHeight={small ? 32 : dense ? 30 : 40}
            />
          </Box>
        ) : (
          !slot.image && <Icon className="ClashKit__slotEmpty" name="plus" />
        )}
        <Box className="ClashKit__slotLabel">{slot.name}</Box>
        {fresh && <Box className="ClashKit__slotNew">new</Box>}
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
  readonly issued?: IssueItem;
  readonly label?: string;
  readonly blurb?: string;
  readonly picked: boolean;
  readonly disabled?: boolean;
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
            <ContentsHint contents={option?.contents} />
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
    deploy_state,
    respawn_in,
    deploy_block,
    revivable,
    sentry_slot,
    job_class,
    hint,
    progress,
  } = data;

  const [selectedSlot, setSelectedSlot] = useState('primary');
  const [weaponView, setWeaponView] = useState<WeaponView>('primary');
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
  const gunName = primary?.name ?? issue?.primary?.name;
  const sidearm = findOption(menus, faction, 'sidearm', choices.sidearm);
  const sidearmName = sidearm?.name ?? issue?.sidearm?.name;
  const slotGunName = (id: string) =>
    SIDE_ATTACHMENT_SLOTS.includes(id) ? sidearmName : gunName;
  const showSidearm = weaponView === 'sidearm';
  const viewName = showSidearm ? sidearmName : gunName;
  const current = slotById[selectedSlot];
  const ranks = progress?.ranks ?? {};
  const slotOptions = (id: string) =>
    (menus[faction]?.[id] ?? []).filter(
      (option) => !option.only_class || option.only_class === job_class,
    );
  const hasClassPerks = slotOptions('class_perk').length > 0;
  useEffect(() => {
    if (selectedSlot === 'class_perk' && !hasClassPerks) {
      setSelectedSlot('general_perk');
    }
  }, [job]);
  const options = slotOptions(selectedSlot)
    .filter(
      (option) =>
        !slotById[selectedSlot]?.attachment ||
        !slotGunName(selectedSlot) ||
        fits.includes(option.id),
    )
    .sort((a, b) => (ranks[a.id] ?? 0) - (ranks[b.id] ?? 0));
  const issueFor = (id: string) => issueForSlot(id, choices, issue);
  const issued = issueFor(selectedSlot);
  const issuedOption = issued?.type
    ? options
        .filter(
          (option) =>
            option.type === issued.type ||
            issued.type?.startsWith(`${option.type}/`),
        )
        .sort((a, b) => b.type.length - a.type.length)[0]
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

  const tile = (
    id: string,
    small?: boolean,
    dimmed?: boolean,
    dense?: boolean,
  ) => (
    <SlotTile
      key={id}
      slot={slotById[id]}
      picked={findOption(menus, faction, id, choices[id])}
      issued={issueFor(id)}
      selected={selectedSlot === id}
      small={small}
      dimmed={dimmed}
      dense={dense}
      lock={choices[id] ? locks[choices[id]] : undefined}
      fresh={
        selectedSlot !== id &&
        slotOptions(id).some((option) => fresh.includes(option.id))
      }
      onClick={() => {
        setSelectedSlot(id);
        setWeaponView((view) => weaponViewFor(id) ?? view);
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
                  <Box className="ClashKit__slotColumn ClashKit__slotColumn--dense">
                    {LEFT_SLOTS.map((id) => tile(id, false, false, true))}
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
                    <Box
                      className={classes([
                        'ClashKit__pouchRow',
                        sentry_slot && 'ClashKit__pouchRow--wide',
                      ])}
                    >
                      {POUCH_SLOTS.map((id) => tile(id, true))}
                      {!!sentry_slot && tile('sentry', true)}
                    </Box>
                  </Box>
                  <Box className="ClashKit__slotColumn">
                    {RIGHT_SLOTS.map((id) => tile(id))}
                  </Box>
                </Box>

                <Box className="ClashKit__attachBar">
                  <AttachmentGroup
                    name={viewName}
                    sidearm={showSidearm}
                    tiles={(showSidearm
                      ? SIDE_ATTACHMENT_SLOTS
                      : ATTACHMENT_SLOTS
                    ).map((id) => tile(id, true, !viewName))}
                  />
                  <Box>
                    <Box className="ClashKit__attachHeader">Perks</Box>
                    <Box className="ClashKit__attachRow">
                      {hasClassPerks && tile('class_perk', true)}
                      {tile('general_perk', true)}
                    </Box>
                  </Box>
                </Box>
                <WeaponPreview
                  image={showSidearm ? data.sidearm : data.gun}
                  sidearm={showSidearm}
                  pending={!!doll_pending}
                  progress={showSidearm ? progress?.sidearm_gun : progress?.gun}
                />
              </Stack.Item>

              <Stack.Item grow className="ClashKit__optionsPanel">
                <Box className="ClashKit__tabs">
                  {(
                    [
                      ['gear', current?.name ?? 'Gear'],
                      [
                        'pack',
                        packProblems
                          ? `Pack · ${packProblems} ${packProblems === 1 ? 'problem' : 'problems'}`
                          : 'Pack',
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
                        id === 'pack' &&
                          !!packProblems &&
                          'ClashKit__tab--warn',
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
                          ? (issued.desc ?? '')
                          : PERK_SLOTS.includes(selectedSlot)
                            ? 'Spawn without a perk'
                            : current?.attachment
                              ? 'Leave this slot empty'
                              : 'Nothing in this slot'
                      }
                      picked={!choices[selectedSlot]}
                      onClick={() => act('clear', { slot: selectedSlot })}
                    />
                  )}
                  {options.map((option) => {
                    const unfit =
                      !!current?.attachment &&
                      (!slotGunName(selectedSlot) || !fits.includes(option.id));
                    const isIssue = option.id === issuedOption?.id;
                    const lock = isIssue ? undefined : locks[option.id];
                    return (
                      <OptionRow
                        key={option.id}
                        option={option}
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
                <Button
                  icon="rotate-left"
                  color="transparent"
                  tooltip="Clear every pick in this kit"
                  onClick={() => act('reset')}
                >
                  Reset
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
