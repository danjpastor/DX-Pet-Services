# Third-Party Notices

## Battle Pet BreedID

DX Pet Services includes breed calculation logic and compiled pet breed/base-stat data derived from **Battle Pet BreedID** by Simca/MMOSimca.

- Project: Battle Pet BreedID
- Author: Simca / MMOSimca and contributors
- Source: https://github.com/MMOSimca/BattlePetBreedID
- Upstream version reviewed for this integration: v1.41.0 / main branch, June 2026
- License listed by the upstream distribution: MIT

The tooltip behavior reproduced by DX Pet Services follows Battle Pet BreedID's default breed-tooltip information set. DX Pet Services uses its own namespaced implementation and UI frames so it can coexist with the upstream addon.

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## AllTheThings (ATT)

DX Pet Services includes a generated, reduced NPC-to-pet source index derived from the public database of **AllTheThings** by the ATTWoWAddon contributors.

- Project: AllTheThings (ATT)
- Source: https://github.com/ATTWoWAddon/AllTheThings
- Upstream data version used for this integration: 5.2.8
- License: MIT
- Included derivative: reduced pet-source relationships, static source coordinates, wild-pet zone rosters/coordinates, boss-to-pet relationships, and instance groupings used by DX Pet Services

The full ATT database and ATT runtime are not bundled. DX Pet Services transforms only the pet-source, wild-pet zone roster, and lightweight world/encounter relationships required by its NPC indicators, map pins, Pet Tracker, boss markers, and dungeon tooltip feature.

### ATT MIT License

MIT License

Copyright (c) 2026 AllTheThings WoW Addon

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
