import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync('.github/workflows/main.yml', 'utf8')
const step = (name) => {
  const steps = workflow.split(/^      - name: /m)
  const matches = steps.filter((s) => s.startsWith(`${name}\n`))
  assert.equal(matches.length, 1, `expected one ${name} step`)
  return matches[0]
}

test('the published registry tarball is attested and the same bundle is attached', () => {
  const pack = step('Pack the published tarball')
  assert.match(pack, /^        if: steps\.prepare\.outputs\.version != ''$/m)
  assert.match(pack, /npm pack "@sasjs\/core@\$\{version\}" --pack-destination dist/)
  const attest = step('Attest the build provenance of that tarball')
  assert.match(attest, /^        if: steps\.pack\.outputs\.version != ''$/m)
  assert.match(attest, /^        uses: sasjs\/release\/\.github\/actions\/attest-assets@6bce05cbcd9364c7097f089ea6c9132978a500ca/m)
  assert.match(attest, /^          subject-path: 'dist\/\*\.tgz'$/m)
  assert.match(attest, /^          version: \$\{\{ steps\.pack\.outputs\.version \}\}$/m)
  const attach = step('Attach the tarball and its provenance to the release')
  assert.match(attach, /^        if: steps\.pack\.outputs\.version != ''$/m)
  assert.match(attach, /^          BUNDLE: \$\{\{ steps\.attest\.outputs\.bundle-path \}\}$/m)
  assert.match(attach, /gh release upload "v\$\{VERSION\}" dist\/\*\.tgz "\$BUNDLE" --clobber/)
  assert.match(workflow, /^      id-token: write\b/m)
  assert.match(workflow, /^      attestations: write\b/m)
  assert.ok(workflow.indexOf(pack) < workflow.indexOf(attest) && workflow.indexOf(attest) < workflow.indexOf(attach))
})
