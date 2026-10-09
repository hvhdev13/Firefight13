import { type BooleanLike, classes } from 'common/react';
import { type ReactNode, useEffect, useRef, useState } from 'react';
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
  fixed?: BooleanLike;
}

interface PackItem {
  type: string;
  name: string;
  icon: string;
  icon_state: string;
  extra: BooleanLike;
  extra_index: number;
  unassigned: BooleanLike;
  fits: string[];
  contents?: string[];
}

interface PackContainer {
  name: string;
  capacity: string;
  items: PackItem[];
  type: string;
  slot: string;
  shells?: string[];
  fill?: string;
}

interface Extra {
  id: string;
  index: number;
  name: string;
  icon: string | null;
  icon_state: string | null;
  slot: string | null;
  status: 'ok' | 'room' | 'points' | 'gone' | 'locked' | 'pending';
}

interface LeftBehind {
  index: number;
  type: string;
  name: string;
  icon: string;
  icon_state: string;
  from: string | null;
  fits: string[];
}

interface FailedMove {
  index: number;
  name: string;
  icon: string;
  icon_state: string;
  from: string | null;
  to: string;
}

type PackDrag = { fits: string[] } & (
  | { extra: number }
  | { type: string; from: string }
  | { removed: number }
);

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
  back_gun?: GunProgress;
}

interface StaticData {
  slots: Slot[];
  menus: Record<string, Record<string, Option[]>>;
  roles: RoleGroup[];
  kit_count: number;
  role_names: Record<string, string>;
}

interface Data extends StaticData {
  job: string;
  faction: string;
  kits: KitSummary[];
  kit_index: number;
  choices: Record<string, string>;
  issue: Record<string, IssueItem>;
  fits: string[];
  blocked_slots: Record<string, string>;
  option_problems: Record<string, string>;
  problems: Record<string, string>;
  notes: Record<string, string>;
  primary_shells: string[] | null;
  back_shells: string[] | null;
  primary_shell: string;
  back_gun_slot: BooleanLike;
  doll: string | null;
  gun: string | null;
  sidearm: string | null;
  back_gun: string | null;
  doll_pending: BooleanLike;
  deploy_state: 'lobby' | 'dead' | null;
  respawn_in: number;
  deploy_block: string | null;
  revivable: BooleanLike;
  sentry_slot: BooleanLike;
  job_class: string;
  class_primaries: BooleanLike;
  hint: string | null;
  pack: PackContainer[];
  extras: Extra[];
  removed: LeftBehind[];
  failed_moves: FailedMove[];
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

const WEAPON_TAB_LABELS: Record<WeaponView, string> = {
  primary: 'Primary',
  sidearm: 'Sidearm',
  back: 'Scabbard',
};

const AttachmentGroup = (props: {
  readonly view: WeaponView;
  readonly scabbard: boolean;
  readonly setView: (view: WeaponView) => void;
  readonly tiles: ReactNode[];
}) => {
  const { view, scabbard, setView, tiles } = props;
  const views: WeaponView[] = scabbard
    ? ['primary', 'sidearm', 'back']
    : ['primary', 'sidearm'];
  return (
    <Box>
      <Box className="ClashKit__attachHeader ClashKit__weaponTabs">
        {views.map((id) => (
          <Box
            key={id}
            as="span"
            className={classes([
              'ClashKit__weaponTab',
              id === view && 'ClashKit__weaponTab--selected',
            ])}
            onClick={() => setView(id)}
          >
            {WEAPON_TAB_LABELS[id]}
          </Box>
        ))}
      </Box>

      <Box className="ClashKit__attachRow">{tiles}</Box>
    </Box>
  );
};

const ShellPicker = (props: { readonly shells?: string[] | null }) => {
  const { act, data } = useBackend<Data>();
  const { shells } = props;
  if (!shells?.length) return null;
  return (
    <Box>
      <Box className="ClashKit__attachHeader">Shells</Box>
      <Box className="ClashKit__shellRow">
        {shells.map((shell) => (
          <Button
            key={shell}
            selected={shell === data.primary_shell}
            onClick={() => act('gun_fill', { shell })}
          >
            {shell}
          </Button>
        ))}
      </Box>
    </Box>
  );
};

const WeaponPreview = (props: {
  readonly image: string | null;
  readonly scale: number;
  readonly empty: string;
  readonly pending: boolean;
  readonly progress?: GunProgress;
}) => {
  const { image, scale, empty, pending, progress } = props;
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
            maxScale={scale}
            whole
          />
        ) : (
          <Box className="ClashKit__gunEmpty">{empty}</Box>
        )}
      </Box>
      {progress && <GunPanel gun={progress} />}
    </>
  );
};

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

const ProblemMark = (props: { readonly text?: string }) =>
  props.text ? (
    <Tooltip content={props.text}>
      <Icon name="circle-exclamation" className="ClashKit__problemMark" />
    </Tooltip>
  ) : null;

const ItemIcon = (props: { readonly icon: string; readonly state: string }) => (
  <Box className="ClashKit__optionIcon">
    <DmIcon
      icon={props.icon}
      icon_state={props.state}
      fallback={<Icon name="spinner" spin />}
    />
  </Box>
);

const dropProps = (
  accepts: boolean,
  over: boolean,
  setOver: (over: boolean) => void,
  onDrop: () => void,
) => ({
  onDragOver: (event: React.DragEvent) => {
    if (!accepts) return;
    event.preventDefault();
    if (!over) setOver(true);
  },
  onDragLeave: () => setOver(false),
  onDrop: (event: React.DragEvent) => {
    event.preventDefault();
    setOver(false);
    if (accepts) onDrop();
  },
});

const PackRow = (props: {
  readonly icon: string | null;
  readonly iconState: string | null;
  readonly name: string;
  readonly bought?: boolean;
  readonly contents?: string[];
  readonly drag: PackDrag;
  readonly setDrag: (drag: PackDrag | null) => void;
  readonly removeTip: string;
  readonly removeIcon?: string;
  readonly onRemove: () => void;
}) => {
  const {
    icon,
    iconState,
    name,
    bought,
    contents,
    drag,
    setDrag,
    removeTip,
    removeIcon = 'xmark',
    onRemove,
  } = props;
  return (
    <div
      className="ClashKit__packItem ClashKit__packItem--drag"
      draggable
      onDragStart={(event) => {
        event.dataTransfer.setData('text/plain', name);
        setDrag(drag);
      }}
      onDragEnd={() => setDrag(null)}
    >
      <Stack align="center">
        <Stack.Item>
          {icon && iconState !== null ? (
            <ItemIcon icon={icon} state={iconState} />
          ) : (
            <Box className="ClashKit__optionIcon" />
          )}
        </Stack.Item>
        <Stack.Item grow>
          {name}
          <ContentsHint contents={contents} />
          {bought && (
            <Box as="span" className="ClashKit__packBought">
              bought
            </Box>
          )}
        </Stack.Item>
        <Stack.Item>
          <Button
            icon={removeIcon}
            color="transparent"
            tooltip={removeTip}
            onClick={onRemove}
          />
        </Stack.Item>
      </Stack>
    </div>
  );
};

const ProblemRow = (props: {
  readonly icon: string | null;
  readonly iconState: string | null;
  readonly name: string;
  readonly reason: string;
  readonly removeTip: string;
  readonly onRemove: () => void;
}) => {
  const { icon, iconState, name, reason, removeTip, onRemove } = props;
  return (
    <Box className="ClashKit__packItem ClashKit__packProblem">
      <Stack align="center">
        <Stack.Item>
          {icon && iconState !== null ? (
            <ItemIcon icon={icon} state={iconState} />
          ) : (
            <Box className="ClashKit__optionIcon" />
          )}
        </Stack.Item>
        <Stack.Item grow>
          {name}
          <Box className="ClashKit__packProblemReason">
            <Icon name="triangle-exclamation" /> {reason}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="xmark"
            color="transparent"
            tooltip={removeTip}
            onClick={onRemove}
          />
        </Stack.Item>
      </Stack>
    </Box>
  );
};

const ExtraProblems = (props: { readonly problems: Extra[] }) => {
  const { act } = useBackend<Data>();
  return (
    <>
      {props.problems.map((extra) => (
        <ProblemRow
          key={`extra${extra.index}`}
          icon={extra.icon}
          iconState={extra.icon_state}
          name={extra.name}
          reason={EXTRA_PROBLEMS[extra.status]}
          removeTip="Take it off the list"
          onRemove={() => act('unbuy', { index: extra.index })}
        />
      ))}
    </>
  );
};

const problemLabel = (count: number) =>
  `${count} ${count === 1 ? 'problem' : 'problems'}`;

const UnassignedBox = (props: {
  readonly items: PackItem[];
  readonly problems: Extra[];
  readonly drag: PackDrag | null;
  readonly setDrag: (drag: PackDrag | null) => void;
}) => {
  const { act } = useBackend<Data>();
  const { items, problems, drag, setDrag } = props;
  const [over, setOver] = useState(false);
  const accepts = !!drag && 'extra' in drag;
  if (!items.length && !problems.length && !accepts) return null;
  return (
    <div
      className={classes([
        'ClashKit__packHolder',
        'ClashKit__packHolder--unassigned',
        !!problems.length && 'ClashKit__packHolder--warn',
        accepts && 'ClashKit__packHolder--target',
        over && 'ClashKit__packHolder--drop',
      ])}
      {...dropProps(accepts, over, setOver, () => {
        if (drag && 'extra' in drag) {
          act('assign_extra', { index: drag.extra, to: '' });
        }
      })}
    >
      <Box className="ClashKit__packHead">
        <Box as="span">Unassigned</Box>
        {!!problems.length && (
          <Box as="span" className="ClashKit__packHeadWarn">
            {problemLabel(problems.length)}
          </Box>
        )}
      </Box>
      <Box className="ClashKit__packNote">
        Drag bought gear onto a container. Anything left here is packed wherever
        it fits.
      </Box>
      <ExtraProblems problems={problems} />
      {items.map((item) => (
        <PackRow
          key={item.extra_index}
          icon={item.icon}
          iconState={item.icon_state}
          name={item.name}
          bought
          contents={item.contents}
          drag={{ extra: item.extra_index, fits: item.fits }}
          setDrag={setDrag}
          removeTip="Return it and get the points back"
          onRemove={() => act('unbuy', { index: item.extra_index })}
        />
      ))}
    </div>
  );
};

const PackHolder = (props: {
  readonly holder: PackContainer;
  readonly problems: Extra[];
  readonly failedMoves: FailedMove[];
  readonly gearProblem?: string;
  readonly drag: PackDrag | null;
  readonly setDrag: (drag: PackDrag | null) => void;
}) => {
  const { act } = useBackend<Data>();
  const { holder, problems, failedMoves, gearProblem, drag, setDrag } = props;
  const [over, setOver] = useState(false);
  const shown = holder.items.filter((item) => !item.unassigned);
  const accepts = !!drag && drag.fits.includes(holder.slot);
  const source = !!drag && 'from' in drag && drag.from === holder.slot;
  const problemCount =
    problems.length + failedMoves.length + (gearProblem ? 1 : 0);
  return (
    <div
      className={classes([
        'ClashKit__packHolder',
        !!problemCount && 'ClashKit__packHolder--warn',
        drag &&
          !source &&
          (accepts
            ? 'ClashKit__packHolder--target'
            : 'ClashKit__packHolder--refuse'),
        over && 'ClashKit__packHolder--drop',
      ])}
      {...dropProps(accepts, over, setOver, () => {
        if (!drag) return;
        if ('extra' in drag) {
          act('assign_extra', { index: drag.extra, to: holder.slot });
        } else if ('removed' in drag) {
          act('restore_item', { index: drag.removed, to: holder.slot });
        } else {
          act('move_item', {
            type: drag.type,
            from: drag.from,
            to: holder.slot,
          });
        }
      })}
    >
      <Box className="ClashKit__packHead">
        <Box as="span">{holder.name}</Box>
        {!!problemCount && (
          <Box as="span" className="ClashKit__packHeadWarn">
            {problemLabel(problemCount)}
          </Box>
        )}
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
      {gearProblem && (
        <Box className="ClashKit__packNote ClashKit__packProblemReason">
          <Icon name="circle-exclamation" /> {gearProblem}
        </Box>
      )}
      <ExtraProblems problems={problems} />
      {failedMoves.map((move) => (
        <ProblemRow
          key={`move${move.index}`}
          icon={move.icon}
          iconState={move.icon_state}
          name={move.name}
          reason={`No room here any more, stays in ${move.from ?? 'its old spot'}`}
          removeTip="Forget this move"
          onRemove={() => act('cancel_move', { index: move.index })}
        />
      ))}
      {shown.length ? (
        shown.map((item, itemIndex) => (
          <PackRow
            key={itemIndex}
            icon={item.icon}
            iconState={item.icon_state}
            name={item.name}
            bought={!!item.extra}
            contents={item.contents}
            drag={
              item.extra
                ? { extra: item.extra_index, fits: item.fits }
                : { type: item.type, from: holder.slot, fits: item.fits }
            }
            setDrag={setDrag}
            removeTip={
              item.extra
                ? 'Return it and get the points back'
                : 'Leave it behind to make room'
            }
            onRemove={() =>
              act('drop_item', {
                type: item.type,
                from: holder.slot,
                extra: item.extra ? 1 : 0,
                extra_index: item.extra_index,
              })
            }
          />
        ))
      ) : (
        <Box className="ClashKit__packEmpty">Empty</Box>
      )}
    </div>
  );
};

const LeftBehindBox = (props: {
  readonly items: LeftBehind[];
  readonly drag: PackDrag | null;
  readonly setDrag: (drag: PackDrag | null) => void;
}) => {
  const { act } = useBackend<Data>();
  const { items, drag, setDrag } = props;
  const [over, setOver] = useState(false);
  const accepts = !!drag && 'from' in drag;
  if (!items.length && !accepts) return null;
  return (
    <div
      className={classes([
        'ClashKit__packHolder',
        'ClashKit__packHolder--unassigned',
        accepts && 'ClashKit__packHolder--target',
        over && 'ClashKit__packHolder--drop',
      ])}
      {...dropProps(accepts, over, setOver, () => {
        if (drag && 'from' in drag) {
          act('drop_item', { type: drag.type, from: drag.from, extra: 0 });
        }
      })}
    >
      <Box className="ClashKit__packHead">Left behind</Box>
      <Box className="ClashKit__packNote">
        Drag an item onto a container to pack it there.
      </Box>
      {items.map((item) => (
        <PackRow
          key={item.index}
          icon={item.icon}
          iconState={item.icon_state}
          name={item.name}
          drag={{ removed: item.index, fits: item.fits }}
          setDrag={setDrag}
          removeIcon="rotate-left"
          removeTip="Pack it again where it came from"
          onRemove={() => act('restore_item', { index: item.index })}
        />
      ))}
    </div>
  );
};

const PACK_KIT_SLOTS: Record<string, string> = {
  back: 'back',
  belt: 'belt',
  l_store: 'pouch_l',
  r_store: 'pouch_r',
  webbing: 'webbing',
};

const DRAG_SCROLL_ZONE = 0.25;
const DRAG_SCROLL_MIN = 4;
const DRAG_SCROLL_MAX = 20;
const DRAG_SCROLL_ARM = 24;

const useDragScroll = (dragging: boolean, stop: () => void) => {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const list = ref.current?.parentElement;
    if (!dragging || !list) return;
    let start: number | null = null;
    let pointer: number | null = null;
    let armed = false;
    let frame = 0;
    const track = (event: DragEvent) => {
      pointer = event.clientY;
      start = start ?? pointer;
      armed = armed || Math.abs(pointer - start) > DRAG_SCROLL_ARM;
    };
    const step = () => {
      if (armed && pointer !== null) {
        const box = list.getBoundingClientRect();
        const zone = Math.max(48, box.height * DRAG_SCROLL_ZONE);
        const up = (box.top + zone - pointer) / zone;
        const down = (pointer - box.bottom + zone) / zone;
        const push = Math.min(Math.max(up, down), 1);
        if (push > 0) {
          list.scrollTop +=
            Math.sign(down - up) *
            (DRAG_SCROLL_MIN + (DRAG_SCROLL_MAX - DRAG_SCROLL_MIN) * push);
        }
      }
      frame = requestAnimationFrame(step);
    };
    document.addEventListener('dragover', track);
    document.addEventListener('drop', stop);
    document.addEventListener('mousedown', stop);
    frame = requestAnimationFrame(step);
    return () => {
      document.removeEventListener('dragover', track);
      document.removeEventListener('drop', stop);
      document.removeEventListener('mousedown', stop);
      cancelAnimationFrame(frame);
    };
  }, [dragging]);
  return ref;
};

const PackView = () => {
  const { data } = useBackend<Data>();
  const { pack, extras, removed, failed_moves, doll_pending } = data;
  const [drag, setDrag] = useState<PackDrag | null>(null);
  const scrollRef = useDragScroll(!!drag, () => setDrag(null));
  useEffect(() => {
    document
      .querySelector('.ClashKit__packProblem')
      ?.scrollIntoView({ block: 'center' });
  }, []);
  const slots = pack.map((holder) => holder.slot);
  const problems = extras.filter((extra) => EXTRA_PROBLEMS[extra.status]);
  const problemsIn = (slot: string | null) =>
    problems.filter(
      (extra) =>
        (extra.slot && slots.includes(extra.slot) ? extra.slot : null) === slot,
    );
  return (
    <div ref={scrollRef}>
      {!!doll_pending && (
        <Box className="ClashKit__packNote">
          <Icon name="circle-notch" spin /> Repacking...
        </Box>
      )}
      <UnassignedBox
        items={pack.flatMap((holder) =>
          holder.items.filter((item) => item.unassigned),
        )}
        problems={problemsIn(null)}
        drag={drag}
        setDrag={setDrag}
      />
      {!!pack.length && (
        <Box className="ClashKit__packNote">
          Drag items between containers to choose where they go.
        </Box>
      )}
      {pack.map((holder) => (
        <PackHolder
          key={holder.slot}
          holder={holder}
          problems={problemsIn(holder.slot)}
          failedMoves={failed_moves.filter((move) => move.to === holder.slot)}
          gearProblem={data.problems?.[PACK_KIT_SLOTS[holder.slot]]}
          drag={drag}
          setDrag={setDrag}
        />
      ))}
      {!pack.length && !doll_pending && (
        <Box className="ClashKit__packEmpty">
          This kit has nothing to pack into.
        </Box>
      )}
      <LeftBehindBox items={removed} drag={drag} setDrag={setDrag} />
    </div>
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
  const problemOf: Record<string, string> = {};
  for (const extra of extras) {
    owned[extra.id] = (owned[extra.id] ?? 0) + 1;
    if (EXTRA_PROBLEMS[extra.status]) {
      problemOf[extra.id] = EXTRA_PROBLEMS[extra.status];
    }
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
            const problem = problemOf[item.id];
            return (
              <Box
                key={item.id}
                className={classes([
                  'ClashKit__packItem',
                  problem && 'ClashKit__packProblem',
                ])}
              >
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
                    {problem && (
                      <Box className="ClashKit__packProblemReason">
                        <Icon name="triangle-exclamation" /> {problem}
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

const packProblemCount = (data: Data) =>
  data.extras.filter((extra) => EXTRA_PROBLEMS[extra.status]).length +
  data.failed_moves.length +
  Object.values(PACK_KIT_SLOTS).filter((slot) => data.problems?.[slot]).length;

const KitProblems = () => {
  const { data } = useBackend<Data>();
  const count = Object.keys(data.problems ?? {}).length;
  if (!count) return null;
  return (
    <Box className="ClashKit__kitProblems">
      <Icon name="circle-exclamation" className="ClashKit__problemMark" />{' '}
      {count} {count === 1 ? 'problem' : 'problems'} with this kit. Hover the
      red marks to see what is wrong.
    </Box>
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
const BACK_ATTACHMENT_SLOTS = [
  'back_rail',
  'back_muzzle',
  'back_under',
  'back_stock',
];
const PRIMARY_SCALE = 5;
const SIDEARM_SCALE = 8;

type WeaponView = 'primary' | 'sidearm' | 'back';

const WEAPON_VIEWS: Record<
  WeaponView,
  { slot: string; slots: string[]; scale: number; empty: string }
> = {
  primary: {
    slot: 'primary',
    slots: ATTACHMENT_SLOTS,
    scale: PRIMARY_SCALE,
    empty: 'No primary',
  },
  sidearm: {
    slot: 'sidearm',
    slots: SIDE_ATTACHMENT_SLOTS,
    scale: SIDEARM_SCALE,
    empty: 'No sidearm',
  },
  back: {
    slot: 'back_gun',
    slots: BACK_ATTACHMENT_SLOTS,
    scale: PRIMARY_SCALE,
    empty: 'No shotgun in the scabbard',
  },
};

const weaponViewData = (view: WeaponView, data: Data) =>
  ({
    primary: {
      image: data.gun,
      progress: data.progress?.gun,
      shells: data.primary_shells,
    },
    sidearm: {
      image: data.sidearm,
      progress: data.progress?.sidearm_gun,
      shells: null,
    },
    back: {
      image: data.back_gun,
      progress: data.progress?.back_gun,
      shells: data.back_shells,
    },
  })[view];

const NOTHING = 'nothing';
const NOTHING_BLURBS: Record<string, string> = {
  armor: 'Spawn without armor. Your primary goes on your back or in your hands',
  primary: 'Spawn without a primary weapon or its ammo',
  sidearm: 'Spawn without a sidearm or its ammo',
  back: 'Spawn without it. What it holds stays behind',
  belt: 'Spawn without it. What it holds stays behind',
  pouch_l: 'Spawn without it. What it holds stays behind',
  pouch_r: 'Spawn without it. What it holds stays behind',
  webbing: 'Spawn without it. What it holds stays behind',
  sentry: 'Spawn without a sentry',
};

const issueForSlot = (
  id: string,
  choices: Record<string, string>,
  issue: Record<string, IssueItem>,
  evenIfNothing = false,
) => {
  if (!evenIfNothing && choices[id] === NOTHING) return undefined;
  if (ATTACHMENT_SLOTS.includes(id) && choices.primary) return undefined;
  if (SIDE_ATTACHMENT_SLOTS.includes(id) && choices.sidearm) return undefined;
  return issue?.[id];
};

const weaponViewFor = (id: string, scabbard?: boolean): WeaponView | null => {
  if (id === 'back' && scabbard) return 'back';
  if (id === 'sidearm' || SIDE_ATTACHMENT_SLOTS.includes(id)) return 'sidearm';
  if (id === 'back_gun' || BACK_ATTACHMENT_SLOTS.includes(id)) return 'back';
  if (id === 'primary' || ATTACHMENT_SLOTS.includes(id)) return 'primary';
  return null;
};
const PERK_SLOTS = ['class_perk', 'general_perk'];

const ScabbardOptions = () => {
  const { act, data } = useBackend<Data>();
  if (!data.back_gun_slot) return null;
  const locks = data.progress?.locks ?? {};
  const ranks = data.progress?.ranks ?? {};
  const options = [...(data.menus[data.faction]?.back_gun ?? [])].sort(
    (a, b) => (ranks[a.id] ?? 0) - (ranks[b.id] ?? 0),
  );
  return (
    <>
      <Box className="ClashKit__optionsGroup">In the scabbard</Box>
      <OptionRow
        label="No shotgun"
        blurb="The scabbard stays empty"
        picked={!data.choices.back_gun}
        onClick={() => act('clear', { slot: 'back_gun' })}
      />
      {options.map((option) => (
        <OptionRow
          key={option.id}
          option={option}
          lock={locks[option.id]}
          picked={data.choices.back_gun === option.id}
          disabled={!!locks[option.id]}
          onClick={() => act('pick', { slot: 'back_gun', id: option.id })}
        />
      ))}
    </>
  );
};

const pickedFor = (data: Data, id: string) => {
  const picked = findOption(data.menus, data.faction, id, data.choices[id]);
  return id === 'back' && picked && data.back_gun_slot && data.choices.back_gun
    ? { ...picked, icon_state: `${picked.icon_state}_full` }
    : picked;
};

const optionMarks = (
  data: Data,
  slot: string,
  id: string,
  isIssue: boolean,
) => {
  const chosen = data.choices[slot];
  const picked = chosen === id || (isIssue && !chosen);
  return picked
    ? { problem: data.problems?.[slot] }
    : { note: data.option_problems?.[id] };
};

const weaponNames = (
  data: Data,
  issueFor: (id: string) => IssueItem | undefined,
): Record<WeaponView, string | undefined> => {
  const nameOf = (slot: string) =>
    findOption(data.menus, data.faction, slot, data.choices[slot])?.name ??
    issueFor(slot)?.name;
  return {
    primary: nameOf('primary'),
    sidearm: nameOf('sidearm'),
    back: nameOf('back_gun'),
  };
};

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
  readonly blocked?: string;
  readonly problem?: string;
  readonly note?: string;
  readonly fresh?: boolean;
  readonly nothing?: boolean;
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
    blocked,
    problem,
    note,
    fresh,
    nothing,
    onClick,
  } = props;
  const shown = picked ?? issued;
  const perk = PERK_SLOTS.includes(slot.id);
  const label = blocked
    ? `${blocked}.`
    : lock
      ? `${picked?.name}: locked, ${lock}. ${perk ? 'You spawn without it.' : 'The starting item is used at spawn.'}`
      : picked
        ? perk
          ? `${picked.name}: ${picked.blurb}`
          : picked.name
        : issued
          ? issued.name
          : `${slot.name}: nothing`;
  const tooltip = (
    <>
      <Box>{label}</Box>
      {problem && (
        <Box className="ClashKit__tipProblem">
          <Icon name="circle-exclamation" /> {problem}
        </Box>
      )}
      {note && (
        <Box className="ClashKit__tipNote">
          <Icon name="circle-info" /> {note}
        </Box>
      )}
    </>
  );
  return (
    <Tooltip content={tooltip}>
      <Box
        className={classes([
          'ClashKit__slot',
          small && 'ClashKit__slot--small',
          selected && 'ClashKit__slot--selected',
          (dimmed || lock) && !blocked && 'ClashKit__slot--dimmed',
          blocked && 'ClashKit__slot--blocked',
          (picked || nothing) && 'ClashKit__slot--set',
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
        {blocked && <Icon className="ClashKit__slotBlocked" name="xmark" />}
        {problem && !blocked && (
          <Icon
            name="circle-exclamation"
            className="ClashKit__problemMark ClashKit__slotProblem"
          />
        )}
        {note && !problem && (
          <Icon name="circle-info" className="ClashKit__slotNote" />
        )}
        {fresh && <Box className="ClashKit__slotNew">new</Box>}
        {(picked || nothing) && <Box className="ClashKit__slotDot" />}
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
  readonly problem?: string;
  readonly note?: string;
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
    problem,
    note,
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
          {problem && (
            <Box className="ClashKit__packProblemReason">
              <Icon name="circle-exclamation" /> {problem}
            </Box>
          )}
          {note && <Box className="ClashKit__optionNote">({note})</Box>}
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

const DefaultRow = (props: {
  readonly slotId: string;
  readonly issued?: IssueItem;
  readonly attachment: boolean;
  readonly picked: boolean;
}) => {
  const { act } = useBackend<Data>();
  const { slotId, issued, attachment, picked } = props;
  const emptyBlurb = PERK_SLOTS.includes(slotId)
    ? 'Spawn without a perk'
    : attachment
      ? 'Leave this slot empty'
      : 'Nothing in this slot';
  return (
    <OptionRow
      issued={issued}
      label={issued ? issued.name : 'Nothing'}
      blurb={issued ? (issued.desc ?? '') : emptyBlurb}
      picked={picked}
      onClick={() => act('clear', { slot: slotId })}
    />
  );
};

const NothingRow = (props: {
  readonly slotId: string;
  readonly issued?: IssueItem;
  readonly picked: boolean;
}) => {
  const { act } = useBackend<Data>();
  const { slotId, issued, picked } = props;
  if (!issued || issued.fixed || PERK_SLOTS.includes(slotId)) return null;
  return (
    <OptionRow
      label="Nothing"
      blurb={NOTHING_BLURBS[slotId] ?? 'Spawn without it'}
      picked={picked}
      onClick={() => act('nothing', { slot: slotId })}
    />
  );
};

export const ClashKit = () => {
  const { act, data } = useBackend<Data>();
  const {
    slots,
    menus,
    roles,
    role_names,
    job,
    faction,
    kits,
    kit_index,
    choices,
    issue,
    fits,
    blocked_slots,
    doll,
    doll_pending,
    deploy_state,
    respawn_in,
    deploy_block,
    revivable,
    sentry_slot,
    job_class,
    class_primaries,
    hint,
    progress,
  } = data;

  const [selectedSlot, setSelectedSlot] = useState('primary');
  const [weaponView, setWeaponView] = useState<WeaponView>('primary');
  const [tab, setTab] = useState<Tab>('gear');
  const left = pointsLeft(data);
  const packProblems = packProblemCount(data);
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

  useEffect(() => {
    act('refresh');
  }, []);
  const slotById = Object.fromEntries(slots.map((slot) => [slot.id, slot]));
  const issueFor = (id: string) => issueForSlot(id, choices, issue);
  const kit = kits[kit_index - 1];
  const gunNames = weaponNames(data, issueFor);
  const slotGunName = (id: string) => gunNames[weaponViewFor(id) ?? 'primary'];
  const view: WeaponView =
    weaponView === 'back' && !data.back_gun_slot ? 'primary' : weaponView;
  const viewInfo = WEAPON_VIEWS[view];
  const viewData = weaponViewData(view, data);
  const viewName = gunNames[view];
  const current = slotById[selectedSlot];
  const ranks = progress?.ranks ?? {};
  const slotOptions = (id: string) =>
    (menus[faction]?.[id] ?? []).filter((option) =>
      id === 'primary' && class_primaries
        ? option.only_class === job_class
        : !option.only_class || option.only_class === job_class,
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
  const issued = issueForSlot(selectedSlot, choices, issue, true);
  const issuedOption = issued?.type
    ? options
        .filter(
          (option) =>
            option.type === issued.type ||
            issued.type?.startsWith(`${option.type}/`),
        )
        .sort((a, b) => b.type.length - a.type.length)[0]
    : undefined;
  const jobName = role_names[job] ?? job;
  const waiting = deploy_state === 'dead' && waitLeft > 0;
  const deployLabel = deploy_block
    ? 'Cannot deploy'
    : waiting
      ? `Deploy in ${clock(waitLeft)}`
      : `Deploy as ${jobName}`;
  const isUpp = faction === 'UPP';
  const roleOptions = (
    roles.find((group) => group.faction === faction)?.jobs ?? []
  ).map((title) => ({
    value: title,
    displayText: progress?.role_locks[title]
      ? `${role_names[title] ?? title} (${progress.role_locks[title]})`
      : (role_names[title] ?? title),
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
      picked={pickedFor(data, id)}
      issued={issueFor(id)}
      selected={selectedSlot === id}
      small={small}
      dimmed={dimmed}
      dense={dense}
      lock={choices[id] ? locks[choices[id]] : undefined}
      blocked={blocked_slots[id]}
      problem={data.problems?.[id]}
      note={data.notes?.[id]}
      nothing={choices[id] === NOTHING}
      fresh={
        selectedSlot !== id &&
        slotOptions(id).some((option) => fresh.includes(option.id))
      }
      onClick={() => {
        setSelectedSlot(id);
        setWeaponView(
          (view) => weaponViewFor(id, !!data.back_gun_slot) ?? view,
        );
        setTab('gear');
      }}
    />
  );

  return (
    <Window width={1080} height={900} theme={isUpp ? 'crtred' : 'crtblue'}>
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
                  displayText={jobName}
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
                  <KitProblems />
                  <Box className="ClashKit__dollSub">
                    Your {jobName} class
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
                    view={view}
                    scabbard={!!data.back_gun_slot}
                    setView={setWeaponView}
                    tiles={viewInfo.slots.map((id) =>
                      tile(id, true, !viewName),
                    )}
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
                  image={viewData.image}
                  scale={viewInfo.scale}
                  empty={viewInfo.empty}
                  pending={!!doll_pending}
                  progress={viewData.progress}
                />
                <ShellPicker shells={viewData.shells} />
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
                  <NothingRow
                    slotId={selectedSlot}
                    issued={issued}
                    picked={choices[selectedSlot] === NOTHING}
                  />
                  {!issuedOption && (
                    <DefaultRow
                      slotId={selectedSlot}
                      issued={issued}
                      attachment={!!current?.attachment}
                      picked={!choices[selectedSlot]}
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
                        {...optionMarks(data, selectedSlot, option.id, isIssue)}
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
                  {selectedSlot === 'back' && <ScabbardOptions />}
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
