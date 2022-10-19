
const MAX_U64_BIG_INT = BigInt(2 ** 64) - BigInt(1)

const MARKET_ADDRESS = '0x1deec95982be38fe32d02e0c3018a7c6730df74c71b838f40aebcc6d48f6472b'
const MARKET_COINT_TYPE = '0x1::aptos_coin::AptosCoin'
const MARKET_NAME = 'stormstout'

// const getAptosWallet = () => {
//   if ('aptos' in window) {
//       return window.aptos;
//   } else {
//       window.open('https://petra.app/', `_blank`);
//   }
// }

export const Aptos = {
  mounted () {
    const message = 'This is a simple message'
    const nonce = '123'
    let wallet

    window.addEventListener('load', async () => {
      wallet = await connect()
    })

    window.addEventListener('phx:transfer', async (e) => {
      console.log('e.detail:', e.detail)

      const { to, amount } = e.detail
      if (!amount|| !to) return

      const payload = {
        type: 'entry_function_payload',
        function: `0x1::coin::transfer`,
        type_arguments: [MARKET_COINT_TYPE],
        arguments: [
          to,
          `${amount}`
        ]
      }

      try {
        console.log('wallet:', wallet)
        const address = await wallet.account()
				console.log('address:' + address)

        const result = await wallet.signAndSubmitTransaction(payload)

				console.log('transfer:', result)

      } catch (error) {
        console.log('transfer: ', error)
      } finally {
        console.log('finally')
      }
    })

    window.addEventListener('phx:connect-petra', async () => {
      try {
        await window.aptos.connect()
        const response = await window.aptos.signMessage({
          message,
          nonce
        })

        console.log('response', response)
        const { address, signature } = response
        login(address, signature)
        wallet = await connect()
        // wallet = response
      } catch (error) {
        console.log('Sign Message Error:', error)
      }
    })

  }
}

async function connect () {
  const isConnected = await window.aptos.isConnected()
  console.log('isConnected:', isConnected)

  if (isConnected) {
    const account = await window.aptos.account()
    return account
  }
  // } else {
  //   const account = await window.aptos.connect()
  //   const { address } = account
  //   login(address)
  //   return account
  // }
}

function login (address, signature) {
  const form = document.createElement('form')
  const element0 = document.createElement('input')
  const element1 = document.createElement('input')
  const element2 = document.createElement('input')

  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')

  form.method = 'POST'
  form.action = '/auth'

  element0.name = '_csrf_token'
  element0.value = csrfToken
  form.appendChild(element0)

  element1.name = 'wallet_address'
  element1.value = address
  form.appendChild(element1)

  element2.name = 'signature'
  element2.value = signature
  form.appendChild(element2)

  document.body.appendChild(form)

  form.submit()
}
