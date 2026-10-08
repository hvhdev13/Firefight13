import type { BooleanLike } from 'common/react';
import { type CSSProperties, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';
import { Box } from 'tgui/components';
import { Window } from 'tgui/layouts';

interface Card {
  key: string;
  title: string;
  votes: number;
  mine: BooleanLike;
  image?: string | null;
  players?: string | null;
  maps?: number;
}

interface VoteData {
  stage: 'mode' | 'map' | 'between' | 'done';
  mode: string;
  time_left: number;
  time_total: number;
  voters: number;
  players: number;
  is_admin: BooleanLike;
  next_map?: string | null;
  cards: Card[];
}

const AMBER = '#ffb840';
const TEXT = '#e4e8de';
const MUTED = '#848e80';
const ZERO = '#4e564c';
const PANEL = '#1c211d';
const EDGE = '#384137';
const FONT = "Bahnschrift, 'Segoe UI', sans-serif";

const PAD = 32;
const GAP = 24;
const INNER = 12;
const HEADER = 96;
const FOOTER = 64;
const TITLEBAR = 32;
const MIN_WIDTH = 760;

const SHAPES = {
  mode: { width: 220, height: 220, cols: 4 },
  map: { width: 300, height: 150, cols: 3 },
};

const formatTime = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

const Brackets = (props: { readonly color: string }) => {
  const arm = 14;
  const line = `2px solid ${props.color}`;
  const corner = (style: CSSProperties) => (
    <div style={{ position: 'absolute', width: arm, height: arm, ...style }} />
  );
  return (
    <>
      {corner({ top: 0, left: 0, borderTop: line, borderLeft: line })}
      {corner({ top: 0, right: 0, borderTop: line, borderRight: line })}
      {corner({ bottom: 0, left: 0, borderBottom: line, borderLeft: line })}
      {corner({ bottom: 0, right: 0, borderBottom: line, borderRight: line })}
    </>
  );
};

const VoteCard = (props: {
  readonly card: Card;
  readonly stage: 'mode' | 'map';
}) => {
  const { act } = useBackend();
  const { card, stage } = props;
  const [hover, setHover] = useState(false);
  const shape = SHAPES[stage];
  const mine = !!card.mine;
  const lit = mine || hover;
  const subline =
    stage === 'mode'
      ? `${card.maps} ${card.maps === 1 ? 'MAP' : 'MAPS'}`
      : card.players && `${card.players} PLAYERS`;
  return (
    <div
      onClick={() => act('vote', { key: card.key })}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: shape.width + 2 * INNER,
        padding: INNER,
        boxSizing: 'border-box',
        background: PANEL,
        borderRadius: 6,
        border: `${mine ? 2 : 1}px solid ${mine ? AMBER : hover ? '#5a6656' : EDGE}`,
        boxShadow: mine ? `0 0 18px rgba(255, 184, 64, 0.45)` : 'none',
        cursor: 'pointer',
        transition: 'border-color 0.15s, box-shadow 0.15s',
      }}
    >
      <div
        style={{
          position: 'relative',
          width: shape.width,
          height: shape.height,
          background: '#080a09',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          overflow: 'hidden',
        }}
      >
        {!!card.image && (
          <img
            src={resolveAsset(card.image)}
            style={{
              maxWidth: '100%',
              maxHeight: '100%',
              imageRendering: stage === 'mode' ? 'pixelated' : 'auto',
            }}
          />
        )}
        <Brackets color={lit ? AMBER : '#64725f'} />
        {mine && (
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              padding: '3px 9px',
              background: AMBER,
              color: '#1e180a',
              fontSize: 12,
              fontWeight: 700,
              letterSpacing: 0.5,
            }}
          >
            YOUR VOTE
          </div>
        )}
      </div>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginTop: 14,
          minHeight: 50,
        }}
      >
        <div style={{ minWidth: 0 }}>
          <div
            style={{
              color: TEXT,
              fontSize: stage === 'mode' ? 19 : 20,
              fontWeight: 700,
              textTransform: 'uppercase',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {card.title}
          </div>
          <div
            style={{
              color: MUTED,
              fontSize: 14,
              fontWeight: 600,
              marginTop: 6,
              minHeight: 17,
            }}
          >
            {subline}
          </div>
        </div>
        <div
          style={{
            color: card.votes ? AMBER : ZERO,
            fontSize: 44,
            fontWeight: 700,
            lineHeight: 1,
            paddingLeft: 12,
          }}
        >
          {card.votes}
        </div>
      </div>
    </div>
  );
};

const Header = (props: {
  readonly title: string;
  readonly chip?: string;
  readonly timer?: string;
  readonly fraction: number;
}) => (
  <div
    style={{
      position: 'relative',
      height: HEADER,
      background: '#171b18',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: `0 ${PAD}px 4px`,
      boxSizing: 'border-box',
      backgroundImage:
        'repeating-linear-gradient(-55deg, #2e2919 0 10px, transparent 10px 28px)',
      backgroundSize: '100% 7px',
      backgroundRepeat: 'no-repeat',
    }}
  >
    <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
      <div style={{ color: TEXT, fontSize: 32, fontWeight: 700 }}>
        {props.title}
      </div>
      {!!props.chip && (
        <div
          style={{
            color: AMBER,
            fontSize: 15,
            fontWeight: 600,
            padding: '4px 13px',
            border: `1px solid ${AMBER}`,
            borderRadius: 4,
            background: '#382e16',
            textTransform: 'uppercase',
          }}
        >
          {props.chip}
        </div>
      )}
    </div>
    {!!props.timer && (
      <div style={{ color: AMBER, fontSize: 38, fontWeight: 700 }}>
        {props.timer}
      </div>
    )}
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: 0,
        height: 4,
        background: '#242924',
      }}
    >
      <div
        style={{
          width: `${Math.round(props.fraction * 100)}%`,
          height: '100%',
          background: AMBER,
          transition: 'width 1s linear',
        }}
      />
    </div>
  </div>
);

export const ClashVote = (props) => {
  const { act, data } = useBackend<VoteData>();
  const { stage, cards, mode } = data;
  const voting = stage === 'mode' || stage === 'map';
  const shape = SHAPES[stage === 'mode' ? 'mode' : 'map'];
  const cols = Math.max(1, Math.min(shape.cols, cards.length));
  const rows = Math.max(1, Math.ceil(cards.length / cols));
  const cardWidth = shape.width + 2 * INNER;
  const cardHeight = shape.height + 2 * INNER + 64;
  const width = voting
    ? Math.max(MIN_WIDTH, 2 * PAD + cols * cardWidth + (cols - 1) * GAP)
    : MIN_WIDTH;
  const height = voting
    ? TITLEBAR + HEADER + PAD + rows * cardHeight + (rows - 1) * GAP + FOOTER
    : TITLEBAR + HEADER + 200;
  const noun = stage === 'mode' ? 'mode' : 'map';
  const title =
    stage === 'mode'
      ? 'MODE VOTE'
      : stage === 'done'
        ? 'NEXT ROUND'
        : 'MAP VOTE';
  const fraction =
    voting && data.time_total ? data.time_left / data.time_total : 0;

  return (
    <Window width={width} height={height} title="Vote">
      <Window.Content fitted>
        <div
          style={{
            height: '100%',
            background:
              'repeating-linear-gradient(0deg, #141715 0 1px, #111412 1px 4px)',
            fontFamily: FONT,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <Header
            title={title}
            chip={stage === 'mode' ? undefined : mode}
            timer={voting ? formatTime(data.time_left) : undefined}
            fraction={fraction}
          />
          {voting ? (
            <div
              style={{
                flex: 1,
                display: 'grid',
                gridTemplateColumns: `repeat(${cols}, ${cardWidth}px)`,
                gap: GAP,
                padding: `${PAD}px ${PAD}px 0`,
                alignContent: 'start',
              }}
            >
              {cards.map((card) => (
                <VoteCard
                  key={card.key}
                  card={card}
                  stage={stage as 'mode' | 'map'}
                />
              ))}
            </div>
          ) : (
            <div
              style={{
                flex: 1,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: stage === 'done' ? AMBER : MUTED,
                fontSize: stage === 'done' ? 40 : 22,
                fontWeight: 700,
                textTransform: 'uppercase',
              }}
            >
              {stage === 'done' ? data.next_map || mode : 'Starting...'}
            </div>
          )}
          {voting && (
            <div
              style={{
                height: FOOTER,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: `0 ${PAD}px`,
                color: MUTED,
                fontSize: 15,
                fontWeight: 600,
              }}
            >
              <div>
                Click a {noun} to vote. Click another {noun} to change your
                vote.
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
                {!!data.is_admin && (
                  <Box
                    as="span"
                    style={{ cursor: 'pointer', textDecoration: 'underline' }}
                    onClick={() => act('cancel')}
                  >
                    Cancel vote
                  </Box>
                )}
                <div>
                  {data.voters} OF {data.players} PLAYERS VOTED
                </div>
              </div>
            </div>
          )}
        </div>
      </Window.Content>
    </Window>
  );
};
