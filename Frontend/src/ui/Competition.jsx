import { useQuery } from '@tanstack/react-query'
import { CubingIcon, UiIcon } from '@thewca/wca-components'
import { marked } from 'marked'
import React, { Fragment, useContext, useMemo } from 'react'
import { Trans, useTranslation } from 'react-i18next'
import { useParams } from 'react-router-dom'
import { Flag, Header, Image, List, Segment } from 'semantic-ui-react'
import getCompetitionInfo from '../api/competition/get/get_competition_info'
import {
  bookmarkCompetition,
  unbookmarkCompetition,
} from '../api/competition/post/bookmark_competition'
import { CompetitionContext } from '../api/helper/context/competition_context'
import { UserContext } from '../api/helper/context/user_context'
import {
  competitionContactFormRoute,
  competitionsPDFRoute,
  userProfileRoute,
} from '../api/helper/routes'
import { getBookmarkedCompetitions } from '../api/user/get/get_bookmarked_competitions'
import { getMediumDateString } from '../lib/dates'
import AddToCalendar from '../pages/schedule/AddToCalendar'
import logo from '../static/wca2020.svg'
import { setMessage } from './events/messages'
import LoadingMessage from './messages/loadingMessage'

export default function Competition({ children }) {
  const { competition_id } = useParams()

  const { user } = useContext(UserContext)

  const { t } = useTranslation()

  const { isLoading, data: competitionInfo } = useQuery({
    queryKey: [competition_id],
    queryFn: () => getCompetitionInfo(competition_id),
  })

  const {
    data: bookmarkedCompetitions,
    isFetching: bookmarkLoading,
    refetch,
  } = useQuery({
    queryKey: [user?.id, 'bookmarks'],
    queryFn: () => getBookmarkedCompetitions(),
    enabled: user !== null,
  })

  const competitionIsBookmarked = (bookmarkedCompetitions ?? []).includes(
    competitionInfo?.id,
  )

  // Hack before we have an image Icon field in the DB
  const src = useMemo(() => {
    if (competitionInfo) {
      const div = document.createElement('DIV')
      div.innerHTML = marked(competitionInfo.information)
      return div.querySelector('img')?.src ?? logo
    }
    return ''
  }, [competitionInfo])

  return (
    <CompetitionContext.Provider
      value={{ competitionInfo: competitionInfo ?? {} }}
    >
      {isLoading ? (
        <LoadingMessage />
      ) : (
        <>
          <Header as="h1" textAlign="center" attached="top">
            <Image
              src={src}
              className="competition-info-logo"
              centered
              floated="right"
            />
            {competitionInfo.name}
            <Header.Subheader>
              <List horizontal>
                {competitionInfo.event_ids.map((event) => (
                  <List.Item key={event}>
                    <CubingIcon
                      event={event}
                      size={
                        event === competitionInfo.main_event_id ? '2x' : '1x'
                      }
                      selected
                    />
                  </List.Item>
                ))}
              </List>
            </Header.Subheader>
          </Header>
          <Segment attached>
            <List divided relaxed size="huge">
              <List.Item>
                <List.Content floated="right">
                  <AddToCalendar
                    startDate={competitionInfo.start_date}
                    endDate={competitionInfo.end_date}
                    name={competitionInfo.name}
                    address={competitionInfo.venue_address}
                    allDay
                  />
                </List.Content>
                <List.Icon name="calendar alternate" />
                <List.Content>
                  {competitionInfo.start_date === competitionInfo.end_date
                    ? getMediumDateString(competitionInfo.start_date)
                    : `${getMediumDateString(
                        competitionInfo.start_date,
                      )} to ${getMediumDateString(competitionInfo.end_date)}`}
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Icon name="globe" />
                <List.Content>
                  {competitionInfo.city}
                  <Flag name={competitionInfo.country_iso2.toLowerCase()} />
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Icon name="home" />
                <List.Content>
                  <List.Header>
                    <p
                      dangerouslySetInnerHTML={{
                        __html: marked(competitionInfo.venue),
                      }}
                    />
                  </List.Header>
                  <List.List>
                    <List.Item>
                      <List.Content floated="right">
                        <a
                          href={`https://google.com/maps/place/${competitionInfo.latitude_degrees},${competitionInfo.longitude_degrees}`}
                          target="_blank"
                        >
                          <UiIcon name="google" />
                        </a>
                      </List.Content>
                      <List.Icon name="map" />
                      <List.Content>
                        {competitionInfo.venue_address}
                      </List.Content>
                    </List.Item>
                    {competitionInfo.venue_details && (
                      <List.Item>
                        <List.Icon name="map signs" />
                        <List.Content>
                          {competitionInfo.venue_details}
                        </List.Content>
                      </List.Item>
                    )}
                  </List.List>
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Icon name="mail" />
                <List.Content>
                  <List.Header>
                    {competitionInfo.contact ? (
                      <span
                        dangerouslySetInnerHTML={{
                          __html: marked(competitionInfo.contact),
                        }}
                      />
                    ) : (
                      <a href={competitionContactFormRoute(competitionInfo.id)}>
                        {t('competitions.competition_info.organization_team')}
                      </a>
                    )}
                  </List.Header>
                  <List.List>
                    <List.Item>
                      <List.Icon name="user circle" />
                      <List.Content>
                        <List.Header>
                          {t(
                            competitionInfo.organizers.length === 1
                              ? 'competitions.competition_info.organizer_plural.one'
                              : 'competitions.competition_info.organizer_plural.other',
                          )}
                        </List.Header>
                        <List.Description>
                          <PersonList people={competitionInfo.organizers} />
                        </List.Description>
                      </List.Content>
                    </List.Item>
                    <List.Item>
                      <List.Icon name="user secret" />
                      <List.Content>
                        <List.Header>
                          {t(
                            competitionInfo.delegates.length === 1
                              ? 'competitions.competition_info.delegate.one'
                              : 'competitions.competition_info.delegate.other',
                          )}
                        </List.Header>
                        <List.Description>
                          <PersonList people={competitionInfo.delegates} />
                        </List.Description>
                      </List.Content>
                    </List.Item>
                  </List.List>
                </List.Content>
              </List.Item>
            </List>
          </Segment>
          {children}
          <Segment padded attached secondary>
            <List divided relaxed>
              <List.Item>
                <List.Icon name="print" />
                <List.Content>
                  <List.Header>
                    {t('competitions.registration_v2.info.download')}
                  </List.Header>
                  <List.List>
                    <List.Item>
                      <List.Icon name="file pdf" />
                      <List.Content>
                        <Trans
                          i18nKey="competitions.registration_v2.pdf.link"
                          values={{ pdfLink: 'PDF' }}
                        >
                          <a href={competitionsPDFRoute(competitionInfo.id)}>
                            PDF
                          </a>
                        </Trans>
                      </List.Content>
                    </List.Item>
                  </List.List>
                </List.Content>
              </List.Item>
              <List.Item>
                <List.Icon
                  link
                  onClick={async () => {
                    if (competitionIsBookmarked) {
                      await unbookmarkCompetition(competitionInfo.id)
                      await refetch()
                      setMessage(
                        t('competitions.registration_v2.bookmark.unbookmark'),
                        'basic',
                      )
                    } else {
                      await bookmarkCompetition(competitionInfo.id)
                      await refetch()
                      setMessage(
                        t('competitions.competition_info.is_bookmarked'),
                        'positive',
                      )
                    }
                  }}
                  name={bookmarkLoading ? 'spinner' : 'bookmark'}
                  color={competitionIsBookmarked ? 'black' : 'grey'}
                />
                <List.Content>
                  <List.Header>
                    {t('competitions.competition_info.bookmark')}
                  </List.Header>
                  <List.Description>
                    {t('competitions.competition_info.number_of_bookmarks', {
                      number_of_bookmarks: competitionInfo.number_of_bookmarks,
                    })}
                  </List.Description>
                </List.Content>
              </List.Item>
            </List>
          </Segment>
        </>
      )}
    </CompetitionContext.Provider>
  )
}

function PersonList({ people }) {
  return people.map((person, index) => (
    <Fragment key={person.id}>
      {index > 0 && ', '}
      {person.wca_id ? (
        <a href={userProfileRoute(person.wca_id)}>{person.name}</a>
      ) : (
        <>{person.name}</>
      )}
    </Fragment>
  ))
}
