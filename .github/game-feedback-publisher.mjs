import {pathToFileURL} from 'node:url';

const endpoint = 'https://guylfe-game-feedback.netlify.app/v2/github-relay';
const DEFINITE_REJECTION = new Set([400, 401, 403, 404, 410, 422, 429]);

export async function publishFeedback({repo, identity, githubToken, fetcher = fetch}) {
  async function relay(command) {
    const response = await fetcher(endpoint, {
      method:'POST', redirect:'error', signal:AbortSignal.timeout(15000),
      headers:{Authorization:'Bearer ' + identity, 'Content-Type':'application/json'},
      body:JSON.stringify(command)
    });
    if (!response.ok) throw Error('Feedback relay returned ' + response.status);
    return response.json();
  }

  const github = (suffix, options = {}) => fetcher('https://api.github.com/repos/' + repo + '/issues' + suffix, {
    ...options, redirect:'error', signal:AbortSignal.timeout(10000),
    headers:{
      Accept:'application/vnd.github+json', Authorization:'Bearer ' + githubToken,
      'Content-Type':'application/json', 'User-Agent':'guylfe-game-feedback'
    }
  });

  async function findIssue(report) {
    const since = new Date(Date.parse(report.attemptedAt) - 60000).toISOString();
    const marker = '<!-- feedback-id:' + report.reportId + ' -->';
    for (let page = 1; page <= 10; page++) {
      const result = await github('?state=all&sort=created&direction=desc&per_page=100&since=' +
        encodeURIComponent(since) + '&page=' + page);
      if (!result.ok) throw Error('GitHub issue lookup returned ' + result.status);
      const entries = await result.json();
      const match = entries.find(issue => !issue.pull_request && issue.user?.login === 'github-actions[bot]' &&
        issue.title === report.issue.title && issue.body?.startsWith(marker));
      if (match) return match.number;
      if (entries.length < 100) break;
    }
    return null;
  }

  const batch = await relay({action:'claim'});
  if (batch.repo !== repo || !Array.isArray(batch.reports) || batch.reports.length > 8) {
    throw Error('Unexpected feedback relay claim response');
  }
  const counts = {claimed:batch.reports.length, confirmed:0, pending:0, failed:0};
  for (const report of batch.reports) {
    const reference = {reportId:report.reportId, claimId:report.claimId};
    try {
      let issueNumber;
      if (report.mode === 'recover') {
        issueNumber = await findIssue(report);
        if (!issueNumber) {
          counts.pending++;
          continue;
        }
      } else if (report.mode === 'create') {
        const response = await github('', {method:'POST', body:JSON.stringify(report.issue)});
        if (response.status !== 201) {
          if (DEFINITE_REJECTION.has(response.status)) {
            await relay({action:'release', ...reference, githubStatus:response.status});
          }
          throw Error('GitHub issue creation returned ' + response.status);
        }
        issueNumber = (await response.json()).number;
      } else {
        throw Error('Unknown feedback claim mode');
      }
      if (!Number.isSafeInteger(issueNumber) || issueNumber <= 0) throw Error('GitHub issue number is invalid');
      await relay({action:'ack', ...reference, issueNumber});
      counts.confirmed++;
    } catch {
      // Report contents, credentials and response bodies can be private.
      counts.failed++;
    }
  }
  return counts;
}

async function main() {
  const identityURL = new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL);
  identityURL.searchParams.set('audience', endpoint);
  const response = await fetch(identityURL, {
    redirect:'error', signal:AbortSignal.timeout(10000),
    headers:{Authorization:'Bearer ' + process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN}
  });
  if (!response.ok) throw Error('GitHub job identity returned ' + response.status);
  const {value} = await response.json();
  const counts = await publishFeedback({
    repo:process.env.GITHUB_REPOSITORY, identity:value, githubToken:process.env.GH_TOKEN
  });
  console.log(JSON.stringify(counts));
  if (counts.failed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => {
    // An unexpected fetch exception may include a URL with internal parameters.
    console.error(error.message === 'fetch failed' ? 'Feedback publisher network request failed.' : error.message);
    process.exitCode = 1;
  });
}
