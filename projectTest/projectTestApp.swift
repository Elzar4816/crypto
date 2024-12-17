import SwiftUI

// Модель для хранения информации о криптовалютах
struct CryptoData: Codable {
    let bitcoin: CryptoInfo
    let ethereum: CryptoInfo
    let litecoin: CryptoInfo
    let dogecoin: CryptoInfo
    let ripple: CryptoInfo
    let cardano: CryptoInfo
    
    struct CryptoInfo: Codable {
        let usd: Double
    }
}

// Модель для работы с API обменных курсов
struct ExchangeRates: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}

// ViewModel для получения и обработки данных о криптовалютах и курсах обмена
class CryptoConverterViewModel: ObservableObject {
    @Published var cryptoPrices: [String: Double] = [:]
    @Published var exchangeRates: [String: Double] = [:]
    @Published var errorMessage: String = ""
    @Published var convertedPrices: [String: Double] = [:]  // Сохраняем конвертированные цены
    @Published var amountToConvert: String = "1"  // По умолчанию 1
    @Published var selectedCurrency: String = "USD"  // Валюта для конвертации

    // Функция для получения данных о криптовалюте
    func fetchCryptoPrices() {
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,litecoin,dogecoin,ripple,cardano&vs_currencies=usd"
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Network Error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }
            
            do {
                let cryptoData = try JSONDecoder().decode(CryptoData.self, from: data)
                
                DispatchQueue.main.async {
                    self.cryptoPrices["bitcoin"] = cryptoData.bitcoin.usd
                    self.cryptoPrices["ethereum"] = cryptoData.ethereum.usd
                    self.cryptoPrices["litecoin"] = cryptoData.litecoin.usd
                    self.cryptoPrices["dogecoin"] = cryptoData.dogecoin.usd
                    self.cryptoPrices["ripple"] = cryptoData.ripple.usd
                    self.cryptoPrices["cardano"] = cryptoData.cardano.usd
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode crypto data. \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    // Функция для получения данных о курсе обмена
    func fetchExchangeRates(from baseCurrency: String) {
        let urlString = "https://api.exchangerate-api.com/v4/latest/\(baseCurrency)"
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Network Error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }
            
            do {
                let exchangeData = try JSONDecoder().decode(ExchangeRates.self, from: data)
                
                // Логирование всех валют
                DispatchQueue.main.async {
                    self.exchangeRates = exchangeData.rates
                    print("Available currencies: \(exchangeData.rates.keys.sorted())")
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode exchange rate data. \(error.localizedDescription)"
                }
            }
        }.resume()
    }


    // Функция для конвертации криптовалюты
    func convertCryptoPrice(cryptoName: String, amount: Double, toCurrency: String) {
        if let cryptoPriceInUSD = cryptoPrices[cryptoName], let exchangeRate = exchangeRates[toCurrency] {
    
            let convertedPrice = cryptoPriceInUSD * amount * exchangeRate
            DispatchQueue.main.async {
                self.convertedPrices[cryptoName] = convertedPrice
            }
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid currencies or rates not available"
            }
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = CryptoConverterViewModel()
    @State private var selectedCurrencies: [String: String] = [:]

    // Функция для форматирования чисел с сокращением
    func formatNumber(_ number: Double) -> String {
        if number >= 1_000_000_000 {
            return String(format: "%.2fB", number / 1_000_000_000)
        } else if number >= 1_000_000 {
            return String(format: "%.2fM", number / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.2fK", number / 1_000)
        } else {
            return String(format: "%.2f", number)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Список криптовалют и их цен
                List(viewModel.cryptoPrices.keys.sorted(), id: \.self) { coin in
                    HStack {
                        Text(coin.capitalized)
                            .font(.system(size: 10))
                            .fontWeight(.bold)
                            .frame(width: geometry.size.width * 0.2, alignment: .leading)
                        
                        Spacer()
                        
                        Picker("Currency", selection: Binding(
                            get: { self.selectedCurrencies[coin] ?? "USD" },
                            set: { newValue in
                                self.selectedCurrencies[coin] = newValue
                                if let price = viewModel.cryptoPrices[coin], let amount = Double(viewModel.amountToConvert) {
                                    viewModel.convertCryptoPrice(cryptoName: coin, amount: amount, toCurrency: newValue)
                                }
                            }
                        )) {
                            ForEach(viewModel.exchangeRates.keys.sorted(), id: \.self) { currency in
                                Text(currency)
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .tag(currency)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 70)


                        
                        // Отображение конвертированной цены и полного названия валюты
                        if let price = viewModel.convertedPrices[coin] {
                            if let currencyName = currencyNames[self.selectedCurrencies[coin] ?? "USD"] {
                                Text("\(formatNumber(price)) \(currencyName)")
                                    .font(.system(size: 10))
                                    .fontWeight(.bold)
                                    .frame(width: geometry.size.width * 0.4, alignment: .trailing)
                            }
                        } else if let price = viewModel.cryptoPrices[coin] {
                            Text("$\(formatNumber(price))")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .frame(width: geometry.size.width * 0.4, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 15)
                }
                .frame(maxWidth: .infinity)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 40)
                }
                
                Spacer()

                // Ошибка
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }

            .padding(0)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                viewModel.fetchCryptoPrices()
                viewModel.fetchExchangeRates(from: "USD")
            }
        }
    }
}


@main
struct CryptoConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
