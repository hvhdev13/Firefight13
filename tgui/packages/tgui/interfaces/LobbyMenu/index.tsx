import { randomInteger } from 'common/random';
import type { BooleanLike } from 'common/react';
import {
  type ComponentProps,
  createContext,
  type PropsWithChildren,
  type ReactNode,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button as NativeButton,
  Flex,
  Modal,
  Section,
  Stack,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import { LobbyBackdrop } from './Backdrop';

type LobbyData = {
  lobby_author: string;
  lobby_map: string;

  character_name: string;
  xeno_prefix: string;
  xeno_postfix: string;

  round_start: BooleanLike;
  readied: BooleanLike;

  confirmation_message?: string | string[];

  upp_enabled: BooleanLike;
  kits_enabled: BooleanLike;
  ready_sides: BooleanLike;
  ready_side: 'uscm' | 'upp' | null;
  xenomorph_enabled: BooleanLike;
  predator_enabled: BooleanLike;
  fax_responder_enabled: BooleanLike;

  preference_issues: string[];

  lobby_music?: string;
  lobby_music_beats?: string;
  lobby_music_credit?: string;
  lobby_music_volume: number;
  lobby_music_on: BooleanLike;
  lobby_effects: BooleanLike;
  lobby_news: string[];
};

type LobbyContextType = {
  animationsDisable: boolean;
  setModal?: (_: ReactNode | false) => void;
};

const LobbyContext = createContext<LobbyContextType>({
  animationsDisable: false,
});

export const LobbyMenu = () => {
  const { act, data } = useBackend<LobbyData>();

  const {
    lobby_author,
    lobby_map,
    confirmation_message,
    preference_issues,
    lobby_music,
    lobby_music_beats,
    lobby_music_credit,
    lobby_music_volume,
    lobby_music_on,
    lobby_effects,
    lobby_news,
  } = data;

  const onLoadPlayer = useRef<HTMLAudioElement>(null);

  const [modal, setModal] = useState<ReactNode | false>(false);

  const [disableAnimations, setDisableAnimations] = useState(false);

  useEffect(() => {
    setTimeout(() => {
      onLoadPlayer.current!.play();
    }, 250);

    setTimeout(() => {
      setDisableAnimations(true);
    }, 10000);
  }, []);

  useEffect(() => {
    if (!confirmation_message) return;

    setModal(
      <Section
        buttons={
          <Button
            mb={5}
            onClick={() => {
              setModal!(false);
              act('unconfirm');
            }}
            icon={'x'}
          />
        }
        p={3}
        title={'Confirm'}
      >
        <Box>
          <Stack vertical>
            {Array.isArray(confirmation_message) ? (
              confirmation_message.map((element, index) => (
                <Stack.Item key={index}>{element}</Stack.Item>
              ))
            ) : (
              <Stack.Item>{confirmation_message}</Stack.Item>
            )}
          </Stack>
          <Stack justify="center">
            <Stack.Item>
              <Button onClick={() => act('confirm')}>Confirm</Button>
            </Stack.Item>
          </Stack>
        </Box>
      </Section>,
    );
  }, [confirmation_message]);

  const [hidden, setHidden] = useState<boolean>(false);

  return (
    <Window theme="crtlobby" fitted scrollbars={false}>
      <audio src={resolveAsset('load.mp3')} ref={onLoadPlayer} />
      <Window.Content className="LobbyScreen" fitted>
        <LobbyContext.Provider
          value={{
            animationsDisable: disableAnimations,
            setModal: setModal,
          }}
        >
          {!!modal && <Modal>{modal}</Modal>}
          <LobbyBackdrop
            music={lobby_music}
            beats={lobby_music_beats}
            credit={lobby_music_credit}
            volume={lobby_music_volume}
            effects={!!lobby_effects}
            news={lobby_news}
            place={lobby_map}
          />
          <Box
            height="100%"
            width="100%"
            style={{
              backgroundImage: `url(${resolveAsset('lobby_art.png')})`,
            }}
            className="bgLoad bgBackground"
          />
          <Box className="feedControls">
            <Button
              icon={lobby_music_on ? 'volume-high' : 'volume-xmark'}
              selected={!!lobby_music_on}
              tooltip={
                lobby_music_on ? 'Mute the lobby music' : 'Play the lobby music'
              }
              onClick={() => act('toggle_lobby_music')}
            />
            <Button
              icon="tv"
              selected={!!lobby_effects}
              tooltip={
                lobby_effects
                  ? 'Turn off the lobby effects'
                  : 'Turn on the lobby effects'
              }
              onClick={() => act('toggle_lobby_effects')}
            />
            {hidden && (
              <Button
                icon="check"
                tooltip="Show the menu"
                onClick={() => setHidden(false)}
              />
            )}
          </Box>
          <Stack vertical height="100%" justify="space-around" align="center">
            <Stack.Item>
              <LobbyButtons
                setModal={setModal}
                hidden={hidden}
                setHidden={setHidden}
              />
            </Stack.Item>
          </Stack>
          <Box className="bgLoad authorAttrib styledText">
            {lobby_author ? `Art by ${lobby_author}` : ''}
          </Box>
          <Box
            position="absolute"
            left={3}
            top={-2}
            height="100%"
            className="messageHolder"
          >
            <Stack vertical justify="flex-end" fill>
              {preference_issues.map((issue, index) => (
                <Section key={index} className="sectionLoad">
                  <Box>{issue}</Box>
                </Section>
              ))}
            </Stack>
          </Box>
        </LobbyContext.Provider>
      </Window.Content>
    </Window>
  );
};

const ModalConfirm = (props: PropsWithChildren) => {
  const { children } = props;

  const context = useContext(LobbyContext);

  const { setModal } = context;

  return (
    <Section
      buttons={<Button mb={5} onClick={() => setModal!(false)} icon={'x'} />}
      p={3}
      title={'Confirm'}
    >
      {children}
    </Section>
  );
};

const SMALL_BUTTON_DELAY = 3;

const LobbyButtons = (props: {
  readonly setModal: (_) => void;
  readonly hidden: boolean;
  readonly setHidden: (_: boolean) => void;
}) => {
  const { act, data } = useBackend<LobbyData>();

  const { setModal, hidden, setHidden } = props;

  const {
    character_name,
    xeno_postfix,
    xeno_prefix,
    round_start,
    readied,
    predator_enabled,
    upp_enabled,
    xenomorph_enabled,
  } = data;

  const [xenoNumber] = useState(`${randomInteger(0, 999)}`);

  return (
    <Section
      p={3}
      className="sectionLoad"
      style={{
        opacity: hidden ? '0' : '1',
      }}
    >
      <Stack vertical>
        <Stack.Item>
          <Stack>
            <Stack.Item>
              <Stack vertical justify="space-around" height="100%">
                <Stack.Item>
                  <Box height="68px">
                    <Box
                      style={{
                        backgroundImage: `url("${resolveAsset('uscm.png')}")`,
                      }}
                      width="67px"
                      className="loadEffect"
                      onClick={() => {
                        setHidden(true);
                      }}
                    />
                  </Box>
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item minWidth="200px">
              <Stack vertical>
                <Stack.Item>
                  <Stack justify="center">
                    <Stack.Item>
                      <Box className="typeEffect styledText">Welcome,</Box>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack justify="center">
                    <Stack.Item>
                      <Box
                        className="typeEffect styledText feedName"
                        style={{
                          animationDelay: '1.4s',
                        }}
                      >
                        {character_name}
                      </Box>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack justify="center">
                    <Stack.Item>
                      <Box
                        className="typeEffect styledText"
                        style={{
                          animationDelay: '1.4s',
                        }}
                      >
                        {`${xeno_prefix}-${xenoNumber}${xeno_postfix}`}
                      </Box>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Stack.Item>

        <TimedDivider />

        <LobbyButton
          index={1}
          onClick={() => act('preferences')}
          icon="file-lines"
        >
          Setup Character
        </LobbyButton>

        <LobbyButton index={2} icon="check-to-slot" onClick={() => act('poll')}>
          Polls
        </LobbyButton>

        <LobbyButton index={3} onClick={() => act('playtimes')} icon="list-ul">
          View Playtimes
        </LobbyButton>

        <TimedDivider />

        <LobbyButton
          index={4}
          icon="eye"
          onClick={() => {
            setModal(
              <ModalConfirm>
                <Box>
                  <Stack vertical>
                    <Stack.Item>Are you sure you wish to observe?</Stack.Item>
                  </Stack>
                  <Stack justify="center">
                    <Stack.Item>
                      <Button onClick={() => act('observe')}>Confirm</Button>
                    </Stack.Item>
                  </Stack>
                </Box>
              </ModalConfirm>,
            );
          }}
        >
          Observe
        </LobbyButton>

        {round_start ? (
          data.ready_sides ? (
            <>
              <Stack.Item>
                <LobbyButton
                  index={5}
                  selected={data.ready_side === 'uscm'}
                  onClick={() => act('ready_uscm')}
                  icon={data.ready_side === 'uscm' ? 'check' : 'xmark'}
                >
                  Ready - USCM
                </LobbyButton>
              </Stack.Item>
              <Stack.Item>
                <LobbyButton
                  index={5 + SMALL_BUTTON_DELAY}
                  selected={data.ready_side === 'upp'}
                  onClick={() => act('ready_upp')}
                  icon={data.ready_side === 'upp' ? 'check' : 'xmark'}
                >
                  Ready - UPP
                </LobbyButton>
              </Stack.Item>
            </>
          ) : (
            <Stack.Item>
              <LobbyButton
                index={5}
                selected={!!readied}
                onClick={() => act(readied ? 'unready' : 'ready')}
                icon={readied ? 'check' : 'xmark'}
                tooltip={
                  xenomorph_enabled ? 'Ready with Xenomorph enabled' : undefined
                }
              >
                {readied ? 'Unready' : 'Ready'}
              </LobbyButton>
            </Stack.Item>
          )
        ) : (
          <>
            <Stack.Item>
              <Stack>
                <Stack.Item grow>
                  <LobbyButton
                    index={5}
                    onClick={() => act('late_join')}
                    icon="users"
                    tooltip={
                      data.kits_enabled
                        ? 'Pick a USCM role and loadout, then deploy'
                        : undefined
                    }
                  >
                    Join the USCM
                  </LobbyButton>
                </Stack.Item>
                <Stack.Item>
                  <LobbyButton
                    icon="list"
                    tooltip="View Crew Manifest"
                    index={5 + SMALL_BUTTON_DELAY}
                    onClick={() => act('manifest')}
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            {!!upp_enabled && (
              <Stack.Item>
                <LobbyButton
                  index={7}
                  onClick={() => act('late_join_upp')}
                  icon="users-between-lines"
                  tooltip={
                    data.kits_enabled
                      ? 'Pick a UPP role and loadout, then deploy'
                      : undefined
                  }
                >
                  Join the UPP
                </LobbyButton>
              </Stack.Item>
            )}
            {!!predator_enabled && (
              <Stack.Item>
                <LobbyButton
                  index={7 + (upp_enabled ? 1 : 0)}
                  onClick={() => {
                    setModal(
                      <ModalConfirm>
                        <Box>
                          <Stack vertical>
                            <Stack.Item>
                              Are you sure want to attempt joining as a
                              Predator?
                            </Stack.Item>
                          </Stack>
                          <Stack justify="center">
                            <Stack.Item>
                              <Button onClick={() => act('late_join_pred')}>
                                Confirm
                              </Button>
                            </Stack.Item>
                          </Stack>
                        </Box>
                      </ModalConfirm>,
                    );
                  }}
                >
                  <Flex>
                    <Flex.Item>
                      <Box className="pred" inline />
                    </Flex.Item>
                    <Flex.Item>Join the Hunt</Flex.Item>
                  </Flex>
                </LobbyButton>
              </Stack.Item>
            )}
          </>
        )}
        {!!data.kits_enabled && (
          <Stack.Item>
            <LobbyButton
              index={round_start ? 6 : 8}
              onClick={() => act('clash_loadout')}
              icon="person-rifle"
              tooltip={
                round_start
                  ? 'Build your kits before the round starts'
                  : 'Build your kits before you deploy'
              }
            >
              Loadout
            </LobbyButton>
          </Stack.Item>
        )}
      </Stack>
    </Section>
  );
};

const TimedDivider = () => {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setTimeout(() => {
      ref.current!.style.display = 'block';
    }, 1500);
  }, []);

  return (
    <Stack.Item>
      <div
        style={{
          borderStyle: 'solid',
          borderWidth: '1px',
          display: 'none',
        }}
        className="dividerEffect"
        ref={ref}
      />
    </Stack.Item>
  );
};

type LobbyButtonProps = ComponentProps<typeof Box> & {
  readonly index: number;
  readonly selected?: boolean;
  readonly disabled?: boolean;
  readonly icon?: string;
  readonly tooltip?: string;
};

const LobbyButton = (props: LobbyButtonProps) => {
  const { children, index, className, ...rest } = props;

  const context = useContext<LobbyContextType>(LobbyContext);

  return (
    <Stack.Item
      className="buttonEffect"
      style={{
        animationDelay: context.animationsDisable
          ? '0s'
          : `${1.5 + index * 0.2}s`,
      }}
    >
      <Button fluid className={'distinctButton ' + className} {...rest}>
        <StyledText>{children}</StyledText>
      </Button>
    </Stack.Item>
  );
};

const StyledText = (props: PropsWithChildren) => {
  const { children } = props;

  return (
    <Box inline className="styledText">
      {children}
    </Box>
  );
};

const Button = (props) => {
  const { act } = useBackend();

  return (
    <Box onClick={() => act('keyboard')}>
      <NativeButton {...props} />
    </Box>
  );
};
